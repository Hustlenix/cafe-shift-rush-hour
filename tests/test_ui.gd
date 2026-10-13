extends SceneTree
## Runs native GUI input through Godot's viewport, not just model calls.
var app: Control
var failures: Array[String] = []
var clicks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _frames(count: int = 3) -> void:
    for _i in range(count):
        await process_frame

func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func _click(node_name: String) -> void:
    var button: Button = app.find_child(node_name,true,false) as Button
    if button == null:
        failures.append("Missing control: "+node_name)
        return
    var parent: Node = button.get_parent()
    while parent != null:
        if parent is ScrollContainer:
            parent.ensure_control_visible(button)
        parent = parent.get_parent()
    await _frames()
    var pos: Vector2 = button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = pos
    root.push_input(motion)
    var down := InputEventMouseButton.new()
    down.position = pos
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    root.push_input(down)
    var up := InputEventMouseButton.new()
    up.position = pos
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    root.push_input(up)
    clicks += 1
    await _frames()

func _capture(name: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    await create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    var path: String = "res://docs/screenshots/"+name+".png"
    var result: Error = root.get_texture().get_image().save_png(path)
    check(result == OK,"Screenshot saved: "+name)

func _run() -> void:
    var store: Node = root.get_node("OrderStore")
    store.persistence_enabled = false
    store.start_shift("FREE")
    app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await _frames(12)
    for category in ["All","Coffee","Tea","Bites","Desserts"]:
        await _click("Category"+category)
        check(app._menu_grid.get_child_count() == {"All":9,"Coffee":3,"Tea":2,"Bites":2,"Desserts":2}[category],"Category "+category)
    await _click("CategoryAll")
    var search: LineEdit = app.find_child("Search",true,false)
    search.text = "honey"
    search.text_changed.emit(search.text)
    await _frames()
    check(app._menu_grid.get_child_count() == 1,"Search filters menu")
    search.text = "no-such-food"
    search.text_changed.emit(search.text)
    await _frames()
    check(app.find_child("Add_latte",true,false) == null,"Empty search state")
    search.clear()
    search.text_changed.emit("")
    await _frames()
    for product in store.MENU:
        await _click("Add_"+str(product["id"]))
    check(store.cart_item_count() == 9,"All nine Add controls")
    for product in store.MENU:
        await _click("Plus_"+str(product["id"]))
        await _click("Minus_"+str(product["id"]))
    check(store.cart_item_count() == 9,"Every quantity control")
    await _capture("till")
    await _click("ClearCart")
    check(store.cart.is_empty(),"Clear cart button")
    await _click("Add_latte")
    app._name.text = "UI Guest"
    app._table.text = "8"
    await _click("SendOrder")
    check(store.orders.size() == 1 and store.orders[0]["customer"] == "UI Guest","GUI order placement")
    # Keyboard activates the kitchen tab using native Button semantics.
    app._tab_kitchen.grab_focus()
    var key := InputEventKey.new()
    key.keycode = KEY_ENTER
    key.pressed = true
    root.push_input(key)
    key = InputEventKey.new()
    key.keycode = KEY_ENTER
    key.pressed = false
    root.push_input(key)
    await _frames()
    check(app._kitchen_page.visible,"Keyboard accepts kitchen tab")
    if store.orders.is_empty():
        for message in failures:
            push_error("FAIL: "+message)
        quit(1)
        return
    var ticket: int = int(store.orders[0]["id"])
    await _click("Advance_%d" % ticket)
    check(store.status_count("PREPARING") == 1,"Kitchen prepare button")
    await _click("Advance_%d" % ticket)
    check(store.status_count("DONE") == 1,"Kitchen done button")
    await _capture("kitchen")
    await _click("TabOrder")
    await _click("Welcome")
    check(store.shift.requests.size() == 2,"Welcome control")
    await _click("Request_R1")
    await _click("Add_latte")
    await _click("SendOrder")
    check(store.orders.size() == 1 and not store.cart.is_empty(),"Wrong request gives feedback and retains cart")
    await _click("Add_croissant")
    await _click("SendOrder")
    check(store.orders.size() == 2,"Exact customer request placed through UI")
    await _click("RushHour")
    check(app._restart.visible,"Rush restart requires confirmation")
    app._restart.get_cancel_button().pressed.emit()
    app._restart.hide()
    check(store.shift.mode == "FREE","Cancel preserves shift")
    await _click("RushHour")
    app._restart.confirmed.emit()
    app._restart.hide()
    await _frames()
    check(store.shift.mode == "RUSH","Rush confirm starts timer")
    await _capture("rush-hour")
    await _click("FreePlay")
    app._restart.confirmed.emit()
    app._restart.hide()
    await _frames()
    check(store.shift.mode == "FREE","Free Play control")
    await _click("Options")
    check(app._options.visible,"Options control")
    var sound: CheckButton = app.find_child("SoundToggle",true,false)
    sound.button_pressed = false
    var motion: CheckButton = app.find_child("MotionToggle",true,false)
    motion.button_pressed = true
    check(not app.sound_on and app.motion_off,"Sound and motion toggles")
    # Dialog buttons belong to separate viewports; native signals are used there.
    var reset: Button = app.find_child("ResetProgress",true,false)
    reset.pressed.emit()
    check(app._reset.visible,"Reset opens confirmation")
    app._reset.confirmed.emit()
    app._reset.hide()
    app._options.hide()
    await _frames()
    check(store.orders.is_empty() and store.xp == 0,"Reset clears progress only after confirmation")
    app.queue_free()
    await _frames()
    for message in failures:
        push_error("FAIL: "+message)
    print("%s: native GUI, %d pointer activations; %d failures" % ["PASS" if failures.is_empty() else "FAIL",clicks,failures.size()])
    quit(0 if failures.is_empty() else 1)
