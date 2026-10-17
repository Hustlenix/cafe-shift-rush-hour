extends RefCounted
## Kitchen commands and handoff feedback, separated from screen construction.
var host: Control

func advance(id: int) -> void:
    if KitchenSync.active:
        if KitchenSync.role != "KITCHEN" or KitchenSync.busy: return
        for order in KitchenSync.orders:
            if int(order["id"]) != id: continue
            if str(order["status"]) == "NEW":
                await KitchenSync.advance(id,"NEW")
                for updated in KitchenSync.orders:
                    if int(updated["id"]) == id and str(updated["status"]) == "PREPARING": host.prep_station.open_ticket(updated,true)
            elif str(order["status"]) == "PREPARING": host.prep_station.open_ticket(order,true)
            return
        return
    var order: Dictionary = OrderStore.find_order(id)
    if order.is_empty() or str(order["status"]) == "DONE": return
    order["hands_on"] = true
    if str(order["status"]) == "NEW": OrderStore.advance_order(id)
    host._notify("Ticket #%d is on the counter. Make each requested item, then serve the tray." % id)
    host.prep_station.open_ticket(order)

func complete(id: int, remote: bool) -> bool:
    if remote:
        if not KitchenSync.active or KitchenSync.busy: return false
        await KitchenSync.advance(id,"PREPARING")
        for order in KitchenSync.orders:
            if int(order["id"]) == id and str(order["status"]) == "DONE":
                host._play("done")
                return true
        return false
    var request_id: String = ""
    for request in OrderStore.shift.requests:
        if int(request["order_id"]) == id: request_id = str(request["id"])
    var previous: int = OrderStore.xp
    if not OrderStore.deliver_crafted(id): return false
    host._play("done")
    host._world.celebrate(request_id)
    var service: Dictionary = OrderStore.shift.last_service
    host._world.float_text(request_id,"+%d XP\n%d%% happy · x%d streak" % [OrderStore.xp-previous,int(service.get("satisfaction",0)),OrderStore.shift.streak],host.GOLD)
    host._notify("Ticket #%d served. +%d XP · quality %d%%" % [id,OrderStore.xp-previous,int(service.get("quality",0))*5])
    return true
