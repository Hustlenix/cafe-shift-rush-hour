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
    store.xp = 0
    store.earnings = 0
    store.served_count = 0
    store.start_shift("FREE")
    app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await _frames(12)
    check(app.selected_request == "R1" and app._request_prompt.text.contains("Amelia"),"First guest and recipe are visible on the till")
    # The café floor is an input surface, not only an illustration. Clear the
    # model's current selection, then select the waiting customer by clicking
    # their drawn actor.
    var world: Control = app._world
    var world_scale: float = minf(world.size.x / 256.0, world.size.y / 192.0)
    var world_origin: Vector2 = (world.size - Vector2(256, 192) * world_scale) / 2.0
    app.selected_request = ""
    var actor_position: Vector2 = world.actors["R1"]["pos"]
    var world_point: Vector2 = world.global_position + world_origin + actor_position * world_scale + Vector2(10, 12) * world_scale
    var floor_click := InputEventMouseButton.new()
    floor_click.position = world_point
    floor_click.button_index = MOUSE_BUTTON_LEFT
    floor_click.pressed = true
    root.push_input(floor_click)
    floor_click = InputEventMouseButton.new()
    floor_click.position = world_point
    floor_click.button_index = MOUSE_BUTTON_LEFT
    floor_click.pressed = false
    root.push_input(floor_click)
    await _frames()
    check(app.selected_request == "R1" and app._request_prompt.text.contains("Amelia"),"Clicking a waiting customer selects their request")
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
    await _click("ClearCart")
    check(store.cart.is_empty(),"Clear cart button")
    await _click("Add_latte")
    check(app._send.disabled and app._request_prompt.text.contains("1/2 items packed"),"A partial recipe cannot be sent")
    await _click("Add_croissant")
    check(not app._send.disabled and app._request_prompt.text.contains("PERFECT MATCH"),"Exact recipe unlocks the kitchen ticket")
    var menu_scroll: ScrollContainer = app._menu_grid.get_parent() as ScrollContainer
    menu_scroll.scroll_vertical = 0
    await _capture("till")
    await _click("SendOrder")
    check(store.orders.size() == 1 and store.orders[0]["customer"] == "Amelia","GUI sends the selected customer's exact order")
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
    check(app._status.text.contains("Watch the gold needle"),"Starting a ticket explains its timing action")
    check(app._brew_meters.has(str(ticket)),"Preparing tickets show the pour timing challenge")
    await _capture("kitchen")
    if app._brew_meters.has(str(ticket)):
        app._brew_meters[str(ticket)].set("elapsed",PI - 0.04)
    else:
        failures.append("Pour timing meter missing for ticket #%d" % ticket)
    await _click("Advance_%d" % ticket)
    check(store.status_count("DONE") == 1,"Kitchen done button")
    check(int(store.orders[0].get("quality_bonus",0)) > 0,"Timing the pour earns a kitchen quality bonus")
    await _capture("kitchen-done")
    await _click("TabOrder")
    await _click("Welcome")
    check(store.shift.requests.size() == 2,"Welcome control")
    await _click("Request_R2")
    await _click("Add_latte")
    await _click("SendOrder")
    check(store.orders.size() == 1 and not store.cart.is_empty() and app._send.disabled,"Wrong recipe is visibly blocked and retained")
    await _click("ClearCart")
    await _click("Add_chai")
    await _click("Add_chai")
    await _click("SendOrder")
    check(store.orders.size() == 2 and store.orders[0]["customer"] == "Adam","Exact second customer request placed through UI")
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
    menu_scroll.scroll_vertical = 0
    await _capture("rush-hour")
    var urgent_request: Dictionary = store.shift.requests[0]
    urgent_request["patience"] = 19.0
    app._process(0.0)
    var urgent_id: String = str(urgent_request["id"])
    var urgent_fill: StyleBoxFlat = app._patience[urgent_id].get_theme_stylebox("fill") as StyleBoxFlat
    check(urgent_fill.bg_color == app.CORAL and app._patience_labels[urgent_id].text == "19s","Urgency countdown turns red with the actual remaining seconds")
    urgent_request["patience"] = 0.0
    store.shift.tick(0.1)
    app._process(0.0)
    check(app.selected_request == "R2" and app._request_prompt.text.contains("Adam"),"A missed guest automatically selects the next waiting request")
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
