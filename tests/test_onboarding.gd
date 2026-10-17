extends SceneTree
## Native input on the real first-time flow; fixtures never write a player's save.
var app: Control
var store: Node
var failures: Array[String] = []
var checks: int = 0
var inputs: int = 0
var completions: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    checks += 1
    if not value: failures.append(message)

func frames(count: int = 4) -> void:
    for _i in range(count): await process_frame

func click(id: String, touch: bool = false) -> void:
    var control: Button = app.find_child(id,true,false)
    check(control != null and control.is_visible_in_tree(),"Visible action " + id)
    if control == null: return
    var ancestor: Node = control.get_parent()
    while ancestor != null:
        if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
        ancestor = ancestor.get_parent()
    await frames()
    var at: Vector2 = control.get_global_rect().get_center()
    for pressed in [true,false]:
        if touch:
            var event := InputEventScreenTouch.new()
            event.index = 0
            event.position = at
            event.pressed = pressed
            root.push_input(event,true)
        else:
            var event := InputEventMouseButton.new()
            event.position = at
            event.button_index = MOUSE_BUTTON_LEFT
            event.pressed = pressed
            root.push_input(event,true)
        inputs += 1
    await frames()

func capture(name: String) -> void:
    if DisplayServer.get_name() == "headless": return
    DirAccess.make_dir_recursive_absolute("res://work/screenshots")
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("res://work/screenshots/"+name+".png") == OK,"Captured running game: " + name)

func _run() -> void:
    store = root.get_node("OrderStore")
    store.persistence_enabled = false
    store.tutorial_completed = false
    store.start_shift("FREE")
    root.min_size = Vector2i.ZERO
    root.size = Vector2i(1440,900)
    app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    store.orders_changed.connect(func():
        if app.flow.state == app.flow.State.TUTORIAL and not store.orders.is_empty() and str(store.orders[0]["status"]) == "DONE":
            completions.append({"xp":store.xp,"duplicate_blocked":not store.advance_order(int(store.orders[0]["id"]))})
    )
    await frames(12)
    check(app.flow.state == app.flow.State.WELCOME and app.flow.welcome.visible,"Fresh launch opens welcome")
    store._process(60)
    check(store.shift.remaining == 180 and not store.gameplay_running,"Welcome freezes the challenge")
    await capture("milestone1-welcome-desktop")
    for resolution in [Vector2i(1440,900),Vector2i(390,844)]:
        root.size = resolution
        await frames(8)
        for id in ["StartRush","StartPractice","TwoDeviceKitchen","LearnCounter"]:
            var action: Button = app.find_child(id,true,false)
            check(root.get_visible_rect().encloses(action.get_global_rect()),id+" fits " +str(resolution))
            check(action.size.y >= 44,"Touch-sized action "+id)
        if resolution.x == 390: await capture("milestone1-welcome-phone")
    await click("StartRush",true)
    check(app.flow.state == app.flow.State.RUSH and store.gameplay_running,"Explicit Rush action starts challenge")
    check(store.shift.remaining <= 180 and store.shift.remaining > 179,"Rush starts at three minutes")
    await click("MainMenu")
    var remaining: float = store.shift.remaining
    await create_timer(0.2).timeout
    check(store.shift.remaining == remaining,"Returning to menu pauses a running shift")
    await click("LearnCounter",true)
    check(app.flow.state == app.flow.State.TUTORIAL and store.shift.mode == "FREE","Tutorial runs locally without clock")
    await click("SkipTutorial",true)
    check(app.flow.state == app.flow.State.WELCOME and not store.tutorial_completed,"Skip returns to welcome without claiming completion")
    check(store.shift.remaining == remaining and store.shift.mode == "RUSH","Skip restores previous paused challenge")
    for resolution in [Vector2i(390,844),Vector2i(1440,900)]:
        root.size = resolution
        await frames(8)
        await click("LearnCounter")
        check(app.flow.step == 0,"Tutorial starts by selecting customer")
        await click("Request_R1",resolution.x == 390)
        check(app.flow.step == 1,"Selecting guest advances guidance")
        await click("Add_cookie")
        check(app._send.disabled and app.flow.prompt.text.contains("Easy fix"),"Wrong item gives recoverable feedback")
        await click("Minus_cookie")
        await click("Add_latte")
        check(app._send.disabled,"Partial recipe cannot be submitted")
        await click("Add_croissant")
        check(app.flow.step == 2 and not app._send.disabled,"Exact recipe unlocks send")
        await capture("milestone1-recipe-"+str(resolution.x))
        await click("SendOrder")
        check(app.flow.step == 3 and store.orders.size() == 1,"A genuine kitchen ticket is printed")
        await click("TabKitchen")
        var ticket: int = app.flow.tutorial_ticket
        await click("Advance_%d" % ticket)
        check(app.flow.step == 5 and store.orders[0]["status"] == "PREPARING","Lesson uses real preparation lifecycle")
        await capture("milestone1-kitchen-"+str(resolution.x))
        var cook: RefCounted = load("res://tests/prep_input.gd").new()
        cook.tree = self
        check(await cook.cook(app.prep_station,resolution.x == 390),"All tutorial items prepared with native gestures")
        var xp_before: int = store.xp
        await click("DeliverPrepared")
        check(completions.size() == (1 if resolution.x == 390 else 2) and int(completions[-1]["xp"]) > xp_before,"Basic timing completes order and demonstrates XP")
        check(not completions.is_empty() and completions[-1]["duplicate_blocked"],"Completed tutorial order cannot reward twice")
        await create_timer(0.9).timeout
        await frames()
        check(app.flow.state == app.flow.State.WELCOME and store.tutorial_completed,"Full tutorial persists completion and offers explicit shift choice")
        check(not store.gameplay_running and store.shift.mode == "RUSH" and store.shift.remaining == remaining,"Tutorial preserves previous play without consuming time")
        check(app.flow.welcome.title.text == "FIRST ORDER COMPLETE!","First service success is clearly acknowledged")
        await capture("milestone1-success-"+str(resolution.x))
    # A real five-order victory through the same menu, cart and kitchen buttons.
    store.start_shift("FREE")
    app.flow.show_welcome()
    await frames()
    await click("StartRush")
    root.gui_embed_subwindows = true
    for i in range(5):
        if store.shift.requests.is_empty(): await click("Welcome")
        var request: Dictionary = store.shift.requests[0]
        await click("Request_"+str(request["id"]))
        for product in request["recipe"]:
            for _j in range(int(request["recipe"][product])): await click("Add_"+str(product))
        await click("SendOrder")
        var ticket: int = int(store.orders[0]["id"])
        await click("TabKitchen")
        await click("Advance_%d" % ticket)
        var cook: RefCounted = load("res://tests/prep_input.gd").new()
        cook.tree = self
        check(await cook.cook(app.prep_station),"Rush items prepared through the physical workspace")
        await click("DeliverPrepared")
        check(store.shift.served == i+1,"Rush guest served through actual controls: "+str(i+1))
        if i < 4: await click("TabOrder")
    check(store.shift.result == "SUCCESS" and app._results.visible,"Five actual GUI orders win the Rush challenge")
    await capture("milestone1-five-order-victory")
    app._results.hide()
    await frames()
    app.flow.show_welcome()
    await click("StartPractice")
    if app._restart.visible:
        app._restart.confirmed.emit()
        app._restart.hide()
        await frames()
    check(app.flow.state == app.flow.State.PRACTICE,"Practice starts untimed play")
    store._process(100)
    check(store.shift.remaining == 180 and store.shift.missed == 0,"Practice has no countdown or walkouts")
    await click("MainMenu")
    await click("TwoDeviceKitchen")
    check(app._sync_dialog.visible and not store.gameplay_running,"Two-device opens original pairing UI with solo clock paused")
    app._sync_dialog.hide()
    await frames()
    check(app.flow.state == app.flow.State.WELCOME,"Closing pairing returns to welcome")
    await click("WelcomeSettings")
    app.find_child("ReplayTutorial",true,false).pressed.emit()
    await frames()
    check(app.flow.state == app.flow.State.TUTORIAL,"Settings can replay lesson")
    await click("SkipTutorial")
    check(store.tutorial_completed,"Replay skip cannot erase completion")
    root.gui_embed_subwindows = false
    store.orders_changed.disconnect(store.orders_changed.get_connections()[-1]["callable"])
    app.queue_free()
    await frames()
    store.gameplay_running = false
    print("PASS" if failures.is_empty() else "FAIL",": onboarding / ",checks," checks / ",inputs," input events / ",failures.size()," failures")
    for message in failures: push_error(message)
    quit(0 if failures.is_empty() else 1)
