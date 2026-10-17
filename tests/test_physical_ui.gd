extends SceneTree
var app: Control
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func frames(count: int = 5) -> void:
    for _i in range(count): await process_frame
func check(value: bool, text: String) -> void:
    checks += 1
    if not value: failures.append(text)
func _run() -> void:
    var store: Node = root.get_node("OrderStore")
    store.persistence_enabled = false
    root.min_size = Vector2i.ZERO
    root.size = Vector2i(1440,900)
    app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await frames(12)
    for resolution in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(390,844),Vector2i(360,800),Vector2i(844,390)]:
        root.size = resolution
        store.start_shift("FREE",0)
        app.flow.playing("FREE")
        await frames(8)
        for product in store.MENU: store.add_item(str(product["id"]))
        var ticket: int = store.place_order("Tasting Table","5")
        app._advance(ticket)
        await frames()
        check(app.prep_station.visible,"Workspace opens "+str(resolution))
        check(not store.advance_order(ticket),"Incomplete physical order cannot be marked done")
        check(root.get_visible_rect().size.x >= app.prep_station.get_combined_minimum_size().x,"No horizontal overflow "+str(resolution))
        var gestures: RefCounted = load("res://tests/prep_input.gd").new()
        gestures.tree = self
        gestures.keyboard_only = resolution == Vector2i(1920,1080)
        check(await gestures.cook(app.prep_station,resolution.x < 700),"All nine recipes respond to real gestures "+str(resolution)+str(gestures.failures))
        check(store.tray_ready(ticket),"Every required physical item is ready")
        var expected: Dictionary = store.find_order(ticket)
        check(int(expected.get("perfect_pours",0)) == 4,"Only the four poured drinks count as perfect pours")
        await app.prep_station._deliver()
        await frames()
        check(not app.prep_station.visible and store.status_count("DONE") == 1,"Delivery finishes exactly once "+str(resolution))
        var xp: int = store.xp
        check(not store.deliver_crafted(ticket) and store.xp == xp,"Repeated delivery cannot duplicate XP")
        root.gui_embed_subwindows = true
        app.flow.show_welcome()
        await frames()
        app._open_sync()
        await frames()
        check(app._sync_dialog.size.x <= root.get_visible_rect().size.x and app._sync_dialog.size.y <= root.get_visible_rect().size.y-40,"Pairing dialog fits "+str(resolution))
        app._sync_dialog.hide()
        app._open_options()
        await frames()
        check(app._options.size.x <= root.get_visible_rect().size.x and app._options.size.y <= root.get_visible_rect().size.y-40,"Settings fit "+str(resolution))
        app._options.hide()
        store.start_shift("RUSH",77)
        app._shown_result = ""
        app.flow.playing("RUSH")
        store.shift.tick(64)
        await frames()
        check(store.shift.events.active_id == "LUNCH" and app.feedback.banner.visible,"Rush event is visible in the actual interface")
        store.shift.tick(180)
        await frames()
        check(app._results.visible and app._results.size.x <= root.get_visible_rect().size.x and app._results.size.y <= root.get_visible_rect().size.y-40,"Scrollable failure report fits "+str(resolution))
        app._results.hide()
        app.flow.show_welcome()
        root.gui_embed_subwindows = false
    app.queue_free()
    await frames()
    store.gameplay_running = false
    print("PASS" if failures.is_empty() else "FAIL",": ",checks," physical UI checks / ",failures.size()," failures")
    for failure in failures: push_error(failure)
    quit(0 if failures.is_empty() else 1)
