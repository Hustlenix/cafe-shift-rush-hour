extends Control
## One kitchen workspace. Offline checkpoints belong to OrderStore; online status stays server-owned.
const Prep = preload("res://scripts/preparation.gd")
const Recipes = preload("res://scripts/recipes.gd")
var host: Control
var bench: Control
var preparation: RefCounted
var ticket_id: int = -1
var product: String = ""
var online: bool = false
var room_id: String = ""
var remote_progress: Dictionary = {}
var order: Dictionary = {}
var items: GridContainer
var heading: Label
var progress: Label
var finish: Button
var skip: Button
var delivering: bool = false
var event_label: Label
var connection: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color("211b22")
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
    add_child(margin)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    margin.add_child(scroll)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation",8)
    scroll.add_child(box)
    var top := HBoxContainer.new()
    box.add_child(top)
    heading = host._label("",18,Color("fff3d2"))
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.custom_minimum_size = Vector2(80,38)
    heading.clip_text = true
    heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    top.add_child(heading)
    top.add_child(host._button("Tickets",close_station,false,"ClosePreparation"))
    skip = host._button("Skip lesson",func():
        close_station()
        host.flow.show_welcome()
    ,false,"SkipPreparationTutorial")
    top.add_child(skip)
    items = GridContainer.new()
    items.columns = 2
    items.add_theme_constant_override("h_separation",8)
    items.add_theme_constant_override("v_separation",6)
    box.add_child(items)
    progress = host._label("",16,Color("fff3d2"))
    progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(progress)
    event_label = host._label("",14,Color("f0be6f"))
    event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_label.hide()
    box.add_child(event_label)
    connection = host._label("",14,Color("6da18b"))
    connection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    connection.hide()
    box.add_child(connection)
    bench = preload("res://scripts/prep_bench.gd").new()
    bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bench.custom_minimum_size.y = 230
    box.add_child(bench)
    finish = host._button("Prepare the requested items",_deliver,true,"DeliverPrepared")
    finish.custom_minimum_size.y = 52
    box.add_child(finish)
    hide()
    set_process(false)
    KitchenSync.changed.connect(_validate_remote)

func open_ticket(value: Dictionary, remote: bool = false) -> void:
    ticket_id = int(value["id"])
    online = remote
    room_id = KitchenSync.room if remote else ""
    order = value if not remote else value.duplicate(true)
    if remote:
        var key: String = room_id + "/" + str(ticket_id)
        if not remote_progress.has(key): remote_progress[key] = {"crafted":{},"preparations":{},"craft_quality":0,"perfect_pours":0}
        for field in remote_progress[key]: order[field] = remote_progress[key][field]
    order["hands_on"] = true
    delivering = false
    heading.text = "TICKET #%d · %s" % [ticket_id,str(order.get("customer","Guest"))]
    skip.visible = host.flow.state == host.flow.State.TUTORIAL
    connection.visible = online
    connection.text = KitchenSync.status if online else ""
    bench.reduced_motion = host.motion_off
    items.columns = 2 if size.x < 700 else 4
    _build_items()
    show()
    set_process(true)
    _next_item()

func _build_items() -> void:
    for child in items.get_children():
        items.remove_child(child)
        child.queue_free()
    for line in order["items"]:
        var id: String = str(line["id"])
        var button: Button = host._button("",func(): select_item(id),false,"Prepare_"+id)
        button.icon = Recipes.texture(id)
        button.expand_icon = true
        button.add_theme_constant_override("icon_max_width",32)
        button.custom_minimum_size.y = 52
        button.add_theme_font_size_override("font_size",14)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        items.add_child(button)
    _refresh()

func select_item(id: String) -> void:
    if delivering or (preparation != null and (preparation.running or preparation.holding)): return
    for line in order["items"]:
        if str(line["id"]) == id and int(order.get("crafted",{}).get(id,0)) >= int(line["qty"]): return
    product = id
    preparation = Prep.new()
    preparation.begin(id,order.get("preparations",{}).get(id,{}))
    preparation.activity_started.connect(_checkpoint)
    preparation.checkpoint.connect(_checkpoint)
    preparation.completed.connect(_crafted)
    preparation.judged.connect(func(rating: String, _kind: String): host._play("perfect" if rating == "PERFECT" else ("prepare" if rating == "GOOD" else "error")))
    bench.bind(preparation,str(OrderStore.find_product(id)["name"]))
    _refresh()

func _checkpoint() -> void:
    if preparation == null: return
    if online:
        var checkpoints: Dictionary = order.get("preparations",{})
        checkpoints[product] = preparation.snapshot()
        order["preparations"] = checkpoints
        _save_remote()
    else: OrderStore.save_preparation(ticket_id,preparation.snapshot())

func _crafted() -> void:
    if online:
        var counts: Dictionary = order.get("crafted",{})
        counts[product] = int(counts.get(product,0))+1
        order["crafted"] = counts
        order["craft_quality"] = int(order.get("craft_quality",0))+preparation.grade()
        order["perfect_pours"] = int(order.get("perfect_pours",0))+preparation.perfect_pours
        order["preparations"].erase(product)
        _save_remote()
    else: OrderStore.record_crafted_item(ticket_id,product,preparation.grade(),preparation.perfect_pours)
    host._play("order")
    preparation = null
    bench.bind(null)
    _refresh()
    call_deferred("_next_item")

func _next_item() -> void:
    if not visible: return
    for line in order["items"]:
        if int(order.get("crafted",{}).get(str(line["id"]),0)) < int(line["qty"]):
            select_item(str(line["id"]))
            return
    bench.tray_order = order
    bench.instruction.text = "Every dish is ready. Serve this tray to finish the ticket."
    finish.grab_focus()

func _refresh() -> void:
    var total: int = 0
    var done: int = 0
    for line in order["items"]:
        var id: String = str(line["id"])
        var count: int = int(order.get("crafted",{}).get(id,0))
        total += int(line["qty"])
        done += count
        var button: Button = items.get_node_or_null("Prepare_"+id)
        if button != null:
            button.text = "%s %d/%d" % [str(OrderStore.find_product(id)["name"]).replace("Butter ","").replace("Honey ",""),count,int(line["qty"])]
            button.disabled = count >= int(line["qty"])
    progress.text = "%d / %d on the tray · %s" % [done,total,"Ready to serve!" if done == total else "Make each item. Checkpoints save as you work."]
    finish.disabled = done != total or delivering or (online and (not KitchenSync.active or KitchenSync.busy or KitchenSync.polling_suspended))
    finish.text = "Serve %s's tray  >" % order.get("customer","Guest") if done == total else "Prepare the requested items first"

func _save_remote() -> void:
    for field in ["crafted","preparations","craft_quality","perfect_pours"]:
        remote_progress[room_id+"/"+str(ticket_id)][field] = order[field]

func _deliver() -> void:
    if finish.disabled or delivering: return
    delivering = true
    _refresh()
    var ok: bool = await host.complete_prepared(ticket_id,online)
    if ok: close_station()
    else:
        delivering = false
        _refresh()
        progress.text = KitchenSync.status if online else "The shift has ended. Return to tickets to see the result."

func close_station() -> void:
    if preparation != null:
        _checkpoint()
        preparation.holding = false
        preparation.running = false
    preparation = null
    bench.bind(null)
    hide()
    set_process(false)

func _validate_remote() -> void:
    if not KitchenSync.active: remote_progress.clear()
    if visible and online and (not KitchenSync.active or KitchenSync.room != room_id): close_station()
    if visible and online:
        connection.text = KitchenSync.status
        connection.add_theme_color_override("font_color",Color("6da18b") if KitchenSync.status.begins_with("Connected") else Color("e7ba72"))
        _refresh()
        for ticket in KitchenSync.orders:
            if int(ticket["id"]) == ticket_id and str(ticket["status"]) == "DONE" and not delivering:
                close_station()
                host._notify("Ticket #%d was completed by another kitchen. The rail is up to date." % ticket_id)

func _unhandled_key_input(event: InputEvent) -> void:
    if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close_station()
        get_viewport().set_input_as_handled()
