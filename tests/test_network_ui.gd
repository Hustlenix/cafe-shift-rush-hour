extends SceneTree
## Actual kitchen UI against the development API. Run with the loopback server already running.
var app: Control
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func frames(count: int = 6) -> void:
    for _i in range(count): await process_frame
func check(value: bool, text: String) -> void:
    checks += 1
    if not value: failures.append(text)
func click(control: Button) -> void:
    var parent: Node = control.get_parent()
    while parent != null:
        if parent is ScrollContainer: parent.ensure_control_visible(control)
        parent = parent.get_parent()
    await frames()
    var window: Window = control.get_window()
    var at: Vector2 = control.get_global_rect().get_center()
    if window != root: at += Vector2(window.position)
    for pressed in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event,true)
    await frames()
func wait_ready(client: Node) -> void:
    var until: int = Time.get_ticks_msec()+15000
    while (client.busy or client._polling) and Time.get_ticks_msec() < until: await process_frame
func _run() -> void:
    var store: Node = root.get_node("OrderStore")
    store.persistence_enabled = false
    store.xp = 0
    var kitchen: Node = root.get_node("KitchenSync")
    kitchen.configure("http://127.0.0.1:8790")
    var till: Node = load("res://scripts/kitchen_sync.gd").new()
    root.add_child(till)
    till.configure("http://127.0.0.1:8790")
    await till.create_room()
    check(till.active,"Real till room created")
    if not till.active:
        till.queue_free()
        quit(1)
        return
    root.min_size = Vector2i.ZERO
    root.gui_embed_subwindows = true
    root.size = Vector2i(390,844)
    app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await frames(12)
    await click(app.find_child("TwoDeviceKitchen",true,false))
    app._sync_endpoint.text = "http://127.0.0.1:8790"
    app._sync_input.text = till.kitchen_code
    await click(app.find_child("JoinRoom",true,false))
    await wait_ready(kitchen)
    if not kitchen.active: print("Join feedback: ",kitchen.status)
    check(kitchen.active and kitchen.role == "KITCHEN","Actual Join button authenticates the kitchen")
    app._sync_dialog.hide()
    await till.submit({"coldbrew":1,"toastie":1},"Network Guest","7")
    await create_timer(2.5).timeout
    check(kitchen.orders.size() == 1 and kitchen.orders[0]["status"] == "NEW","Incoming ticket appears automatically")
    if kitchen.orders.is_empty():
        failures.append("Cannot continue UI preparation without an incoming ticket")
    else:
        var ticket: int = int(kitchen.orders[0]["id"])
        await click(app.find_child("Advance_%d" % ticket,true,false))
        await wait_ready(kitchen)
        await frames()
        check(app.prep_station.visible and kitchen.orders[0]["status"] == "PREPARING","Kitchen UI starts a real server ticket")
        var gestures: RefCounted = load("res://tests/prep_input.gd").new()
        gestures.tree = self
        check(await gestures.cook(app.prep_station,true),"Remote ticket requires actual drink and food preparation")
        await click(app.find_child("DeliverPrepared",true,false))
        await wait_ready(kitchen)
        await frames()
        check(not app.prep_station.visible and kitchen.orders[0]["status"] == "DONE","Prepared tray completes on the backend")
        while till._polling: await process_frame
        await till.poll()
        check(till.orders[0]["status"] == "DONE" and int(till.orders[0]["total"]) == 380,"Till receives completion and server-authoritative total")
        check(store.xp == 0,"Online completion never duplicates offline XP")
    var revoked: Dictionary = await till._api("/api/rooms/"+till.room,HTTPClient.METHOD_DELETE)
    check(revoked.get("ok",false),"Temporary UI test room revoked")
    kitchen.disconnect_room()
    till.disconnect_room()
    app.queue_free()
    till.queue_free()
    await frames()
    print("PASS" if failures.is_empty() else "FAIL",": ",checks," connected kitchen UI checks / ",failures.size()," failures")
    for failure in failures: push_error(failure)
    quit(0 if failures.is_empty() else 1)
