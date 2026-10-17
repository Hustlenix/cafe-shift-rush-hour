extends SceneTree
## Isolated fixtures: these tests never read or overwrite a player's save.
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures.append(description)

func _run() -> void:
    var fresh: Node = load("res://scripts/order_store.gd").new()
    fresh.save_path = "user://new_player_%d.json" % Time.get_ticks_usec()
    fresh._ready()
    check(fresh.shift.mode == "FREE" and not fresh.gameplay_running,"Fresh players enter a paused, untimed welcome state")
    fresh._process(30)
    check(fresh.shift.remaining == 180 and fresh.shift.elapsed == 0,"Welcome does not consume the challenge clock")
    fresh.free()
    var store: Node = load("res://scripts/order_store.gd").new()
    store.persistence_enabled = false
    check(store.place_order("","") == -1,"Empty cart rejected")
    store.add_item("invalid")
    check(store.cart.is_empty(),"Unknown product rejected")
    store.add_item("latte")
    store.add_item("latte")
    store.add_item("chai")
    check(store.cart_total() == 470,"Exact total: 2 latte + chai")
    store.change_quantity("latte",-1)
    check(store.cart_total() == 280,"Quantity decreases update total")
    store.change_quantity("chai",-99)
    check(not store.cart.has("chai"),"Zero quantity removes row")
    store.change_quantity("latte",10000)
    check(store.cart["latte"] == 99,"Quantity cap prevents unbounded cart")
    store.clear_cart()
    store.add_item("latte")
    var id: int = store.place_order("  Test Guest  ","7")
    check(id == 101 and store.cart.is_empty(),"Submit creates ticket and clears cart")
    check(store.orders[0]["customer"] == "Test Guest","Names trimmed")
    check(store.orders[0]["total"] == 190,"Ticket immutable total")
    check(store.advance_order(id) and store.status_count("PREPARING") == 1,"New to Preparing")
    check(store.advance_order(id) and store.status_count("DONE") == 1,"Preparing to Done")
    check(not store.advance_order(id),"No duplicate completion")
    check(store.xp == 25 and store.earnings == 190,"XP/revenue once")
    var quality_id: int = store.place_order(""," ")
    check(quality_id == -1,"A second empty cart is rejected")
    store.add_item("cookie")
    quality_id = store.place_order(""," ")
    check(store.advance_order(quality_id) and store.advance_order(quality_id, 99),"A timed pour completes its ticket")
    check(store.xp == 70 and store.orders[0]["quality_bonus"] == 20,"Perfect pour XP is capped and awarded once")
    check(not store.advance_order(98765),"Unknown order rejected")
    store.start_shift("RUSH", 0)
    check(store.xp == 70,"Starting shift preserves lifetime XP")
    check(store.shift.requests.size() == 2,"Rush starts with two regulars")
    store.add_item("cookie")
    check(store.place_order("","","R1") == -1 and store.cart.has("cookie"),"Wrong recipe rejected without losing cart")
    store.clear_cart()
    store.add_item("latte")
    store.add_item("croissant")
    check(store.place_order("","") == -1,"Rush requires selected request")
    for i in range(5):
        if store.shift.requests.is_empty():
            store.shift.welcome()
        var request: Dictionary = store.shift.requests[0]
        store.clear_cart()
        for key in request["recipe"]:
            for _j in range(int(request["recipe"][key])):
                store.add_item(key)
        var ticket: int = store.place_order("","",str(request["id"]))
        check(ticket > 0,"Correct request accepted %d" % i)
        check(str(request["state"]) == "KITCHEN","Request moves to kitchen %d" % i)
        check(store.place_order("","",str(request["id"])) == -1,"Request cannot be sent twice %d" % i)
        check(store.advance_order(ticket),"Preparation transition %d" % i)
        check(store.advance_order(ticket),"Completion transition %d" % i)
        check(not store.advance_order(ticket),"Reward cannot be duplicated %d" % i)
    check(store.shift.served == 5 and store.shift.result == "SUCCESS" and not store.shift.active,"Five request victory")
    check(store.shift.score > 125,"Prompt service earns bonus XP")
    check(store.served_count == 5,"Exactly five done tickets")
    check(store.shift.tips_total > 0,"Prompt patience earns visible tips")
    check(store.shift.best_streak == 5,"Best streak tracks the five-serve run")
    check(store.record_best(),"A five-serve victory registers as a new best")
    check(not store.record_best(),"The same result cannot set a second record")
    check(int(store.best["score"]) == store.shift.score,"Best score matches the winning shift")
    store.start_shift("RUSH", 0)
    store.shift.tick(66)
    check(store.shift.missed == 2,"Waiting customers leave at patience deadline")
    check(not store.shift.left_out.is_empty(),"A walkout is flagged for floor feedback")
    store.shift.tick(180)
    check(store.shift.result == "TIMEOUT" and not store.shift.active,"Timer failure is explicit")
    # The rush hour builds: every served order tightens the arrival cadence.
    store.start_shift("RUSH", 0)
    check(store.shift.arrival_interval() == 12.0,"A fresh rush starts calm")
    store.shift.requests.clear()
    store.shift.served = 4
    store.shift.arrival_clock = 7.0
    store.shift.tick(1.5)
    check(store.shift.requests.is_empty(),"A hot streak keeps the floor quiet until the quicker interval")
    store.shift.tick(0.4)
    check(store.shift.requests.size() == 1,"The next guest lands on the quicker interval")
    store.shift.served = 9
    check(store.shift.arrival_interval() == 8.0,"The rush pace has a floor")
    store.start_shift("FREE", 0)
    store.shift.tick(1000)
    check(store.shift.requests.size() == 1 and store.shift.requests[0]["patience"] == 65,"Free Play has no timer pressure")
    var meter: Control = load("res://scripts/pour_meter.gd").new()
    meter.set("elapsed", 0.0)
    check(meter.call("quality_bonus") == 20,"Meter center awards a perfect pour")
    meter.set("elapsed", PI / 4.0)
    check(meter.call("quality_bonus") == 0,"Meter edge does not award a pour bonus")
    meter.free()
    # Atomic save round-trip, stale IDs, malformed lines, and legacy schema.
    store.save_path = "user://test_core_fixture.json"
    store.persistence_enabled = true
    store.add_item("matcha")
    var roundtrip: Node = load("res://scripts/order_store.gd").new()
    roundtrip.save_path = store.save_path
    roundtrip.load_data()
    check(roundtrip.cart_total() == 220,"Cart persistence")
    check(roundtrip.xp == store.xp and roundtrip.shift.mode == "FREE","XP and run persistence")
    store.best = {"score": 210, "served": 5, "streak": 5}
    store.save_data()
    roundtrip.load_data()
    check(roundtrip.best["score"] == 210 and roundtrip.best["served"] == 5 and roundtrip.best["streak"] == 5,"Best-shift record round-trips through the save")
    roundtrip.load_data()
    check(roundtrip.cart_item_count() == 1,"Reload is idempotent")
    # Lessons demonstrate the real order API without overwriting an in-progress run.
    var previous: Dictionary = store._snapshot()
    store.begin_tutorial()
    for product in store.shift.requests[0]["recipe"]:
        store.add_item(str(product))
    var lesson_ticket: int = store.place_order("","","R1")
    check(lesson_ticket > 0 and store.advance_order(lesson_ticket) and store.advance_order(lesson_ticket),"Tutorial uses actual validated ticket transitions")
    roundtrip.load_data()
    check(roundtrip.xp == int(previous["xp"]) and roundtrip.cart == previous["cart"] and roundtrip.orders == previous["orders"],"Closing mid-lesson preserves saved progress")
    store.end_tutorial(true)
    roundtrip.load_data()
    check(roundtrip.tutorial_completed,"Tutorial completion survives a new store instance")
    var returning_player: Node = load("res://scripts/order_store.gd").new()
    returning_player.save_path = store.save_path
    returning_player._ready()
    check(returning_player.tutorial_completed and not returning_player.gameplay_running,"Restart loads completion and still pauses at welcome")
    returning_player.free()
    check(roundtrip.xp == int(previous["xp"]) and roundtrip.shift.snapshot() == previous["shift"],"Tutorial restores original XP and entire shift")
    store.begin_tutorial()
    store.end_tutorial(false)
    check(store.tutorial_completed,"Skipping a replay cannot erase completion")
    store.shift.served = 100
    store.shift.best_streak = 100
    var prior_best: Dictionary = store.best.duplicate()
    check(not store.record_best() and store.best == prior_best,"Practice cannot alter competitive records")
    var file: FileAccess = FileAccess.open(store.save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify({"version":1,"cart":{"latte":0,"chai":2,"ghost":2,"cookie":"oops"},"next_order_id":101,"orders":[
        {"id":900,"status":"NEW","items":[{"id":"chai","qty":2,"price":1}]},
        {"id":900,"status":"NEW","items":[{"id":"chai","qty":2}]},
        {"id":901,"status":"BOGUS","items":[]}, {"id":902,"status":"NEW","items":"bad"}
    ]}))
    file.close()
    roundtrip.load_data()
    check(roundtrip.cart_total() == 180 and roundtrip.cart.size() == 1,"Invalid/zero cart values sanitized")
    check(roundtrip.orders.size() == 1 and roundtrip.orders[0]["total"] == 180,"Malformed and duplicate tickets rejected; prices recomputed")
    check(roundtrip.next_order_id == 901,"Next ID cannot collide with restored orders")
    check(roundtrip.best["score"] == 0 and roundtrip.best["streak"] == 0,"Legacy saves start best-shift records at zero")
    for schema in [1,2]:
        file = FileAccess.open(store.save_path,FileAccess.WRITE)
        file.store_string(JSON.stringify({"version":schema,"cart":{"chai":2},"xp":123,"earnings":90,"orders":[{"id":900,"status":"PREPARING","items":[{"id":"chai","qty":1}]}],"shift":{"mode":"RUSH","active":true,"remaining":137,"elapsed":43,"requests":[]},"best":{"score":210}}))
        file.close()
        var legacy: Node = load("res://scripts/order_store.gd").new()
        legacy.save_path = store.save_path
        legacy._ready()
        check(legacy.shift.mode == "RUSH" and legacy.shift.remaining == 137 and not legacy.gameplay_running,"Version %d resumes at welcome without losing saved timer" % schema)
        check(legacy.xp == 123 and legacy.orders[0]["status"] == "PREPARING" and legacy.cart_total() == 180,"Version %d keeps orders, cart and XP" % schema)
        legacy.shift.requests[0]["recipe"] = {"chai":2}
        legacy.save_data()
        legacy.load_data()
        check(legacy.shift.matches(str(legacy.shift.requests[0]["id"]),legacy.cart),"Version %d restored requests still match integer cart quantities" % schema)
        check(not legacy.tutorial_completed,"Version %d defaults new tutorial flag safely" % schema)
        legacy.save_data()
        var upgraded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.save_path))
        check(int(upgraded["version"]) == 4 and int(upgraded["xp"]) == 123,"Version %d migrates safely to version 4" % schema)
        legacy.free()
    file = FileAccess.open(store.save_path,FileAccess.WRITE)
    file.store_string('{"version":999}')
    file.close()
    roundtrip.load_data()
    check(not roundtrip.persistence_enabled,"Unknown future schema preserved without overwriting")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
    store.free()
    roundtrip.free()
    for message in failures:
        push_error("FAIL: "+message)
    print("%s: %d core checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
