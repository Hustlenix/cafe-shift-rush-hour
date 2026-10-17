extends SceneTree
## Real viewport events for the counter loop; timing is stepped deterministically.
var app: Control
var screen: Control
var store: Node
var failures: Array[String] = []
var actions: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value: failures.append(message)

func frames(count: int = 3) -> void:
    for _i in range(count): await process_frame

func pointer(at: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = at
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    root.push_input(event, true)
    actions += 1

func click(at: Vector2) -> void:
    pointer(at, true)
    pointer(at, false)
    await frames()

func button(id: String) -> void:
    var control: Button = app.find_child(id, true, false)
    check(control != null and control.is_visible_in_tree(), "Control exists: " + id)
    if control != null: await click(control.get_global_rect().get_center())

func drag(start: Vector2, finish: Vector2) -> void:
    pointer(start, true)
    var motion := InputEventMouseMotion.new()
    motion.position = finish
    motion.relative = finish - start
    root.push_input(motion, true)
    pointer(finish, false)
    await frames()

func key(code: Key, pressed: bool = true) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = pressed
    root.push_input(event, true)

func touch_drag(start: Vector2, finish: Vector2) -> void:
    var down := InputEventScreenTouch.new()
    down.position = start
    down.index = 0
    down.pressed = true
    root.push_input(down, true)
    var drag_event := InputEventScreenDrag.new()
    drag_event.position = finish
    drag_event.index = 0
    drag_event.relative = finish - start
    root.push_input(drag_event, true)
    var up := InputEventScreenTouch.new()
    up.position = finish
    up.index = 0
    up.pressed = false
    root.push_input(up, true)
    await frames()

func guest_point(id: String) -> Vector2:
    var world: Control = screen.world
    var scale_factor: float = minf(world.size.x / 256, world.size.y / 192)
    return world.global_position + (world.size - Vector2(256, 192) * scale_factor) / 2 + ((world.actors[id]["pos"] as Vector2) + Vector2(8, 12)) * scale_factor

func capture(name: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("res://docs/screenshots/" + name + ".png") == OK, "Screenshot: " + name)

func _prepare_step() -> void:
    var bench: Control = screen.bench
    var prep: RefCounted = screen.preparation
    var at: Vector2 = bench.global_position
    match prep.kind():
        "pick", "plate": await drag(at + bench.food_rect.get_center(), at + bench.plate_rect.get_center())
        "hold":
            var point: Vector2 = at + bench.primary_rect.get_center()
            pointer(point, true)
            check(prep.holding, "Cup filling starts from the physical tap")
            for _i in range(18): prep.tick(0.1)
            if store.shift.served == 0: await capture("counter-brewing")
            pointer(point, false)
            await frames()
        "heat":
            await click(at + bench.primary_rect.get_center())
            check(prep.running, "Equipment starts heating through pointer input")
            for _i in range(29): prep.tick(0.1)
            if store.shift.served == 0: await capture("counter-oven")
            await click(at + bench.primary_rect.get_center())
        "stir":
            if store.shift.served == 0: await capture("counter-whisk")
            var centre: Vector2 = at + bench.primary_rect.get_center()
            pointer(centre, true)
            for i in range(8):
                var motion := InputEventMouseMotion.new()
                motion.position = centre + Vector2(-38 if i % 2 == 0 else 38, 0)
                root.push_input(motion, true)
            pointer(centre, false)
            await frames()
        "stack":
            var index: int = prep.count
            await drag(at + bench.sources[index].get_center(), at + bench.primary_rect.position + bench.primary_rect.size * Vector2(0.5, 0.8))
        "cut":
            await drag(at + bench.primary_rect.position + bench.primary_rect.size * Vector2(0.5, 0.1), at + bench.primary_rect.position + bench.primary_rect.size * Vector2(0.5, 0.9))

func _run() -> void:
    store = root.get_node("OrderStore")
    store.persistence_enabled = false
    store.xp = 0
    store.start_shift("FREE")
    app = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await frames(10)
    screen = app.current
    check(screen.menu.visible and not store.is_processing(), "Opening menu safely pauses the saved shift")
    await button("CounterSound")
    check(not screen.menu.sound.button_pressed and not screen.audio.enabled, "Counter sound toggle disables playback")
    await button("CounterSound")
    await button("CounterMotion")
    check(screen.world.reduced_motion, "Counter motion toggle applies to customer movement")
    await button("Practice")
    check(screen.audio.enabled, "Resuming activates enabled ambience")
    screen.world.reduced_motion = true
    await frames(3)
    check(not screen.menu.visible and store.shift.mode == "FREE", "Practice resumes without a deadline")
    for recipe_index in range(6):
        if recipe_index in [1,2,3,4]:
            root.min_size = Vector2i.ZERO
            root.size = {1:Vector2i(390,844),2:Vector2i(360,640),3:Vector2i(844,390),4:Vector2i(1360,860)}[recipe_index]
            await frames(8)
        var request_id: String = str(store.shift.requests[0]["id"])
        await click(guest_point(request_id))
        check(screen.order_id >= 101 and screen.preparation != null, "World guest opens a physical preparation")
        check(not store.deliver_crafted(screen.order_id), "Incomplete tray cannot be delivered")
        var attempts: int = 0
        while not store.tray_ready(screen.order_id) and attempts < 35:
            attempts += 1
            check(screen.preparation != null, "Pending food always has a preparation")
            if screen.preparation == null: break
            await _prepare_step()
        check(store.tray_ready(screen.order_id), "All physical items finished for recipe " + str(recipe_index))
        if not store.tray_ready(screen.order_id):
            print("Blocked recipe: ", recipe_index, " product=", screen.selected_product, " step=", screen.preparation.index, " kind=", screen.preparation.kind(), " progress=", screen.preparation.progress, " count=", screen.preparation.count)
            await capture("counter-failure")
            for message in failures: push_error(message)
            app.queue_free()
            await frames()
            quit(1)
            return
        if recipe_index == 0:
            await capture("counter-desktop")
            for resolution in [Vector2i(390,844),Vector2i(360,640),Vector2i(844,390),Vector2i(1280,720)]:
                root.min_size = Vector2i.ZERO
                root.size = resolution
                await frames(8)
                var viewport: Rect2 = root.get_visible_rect()
                check(viewport.encloses(screen.bench.get_global_rect()), "Bench fits viewport " + str(resolution))
                check(screen.bench.size.y >= 220 and screen.bench._art.end.y <= screen.bench.keys.position.y, "Equipment and hints fit the bench " + str(resolution))
                check(viewport.encloses(screen.tray.get_global_rect()) and screen.tray.size.y >= 48, "Anchored tray fits " + str(resolution))
                check(not screen.slip.get_global_rect().intersects(screen.bench.get_global_rect()), "Request never scrolls away or overlaps bench " + str(resolution))
                if resolution == Vector2i(390,844): await capture("counter-phone")
                if resolution == Vector2i(360,640): await capture("counter-small-phone")
                if resolution == Vector2i(844,390): await capture("counter-landscape")
            root.size = Vector2i(1360,860)
            await frames(8)
        var previous_xp: int = store.xp
        var other_id: String = ""
        if recipe_index == 0:
            other_id = store.welcome_customer()
            await frames()
        await button("ServingTray")
        check(screen.carrying and store.xp == previous_xp, "Picking up tray awards no XP before handoff")
        if other_id != "":
            await click(guest_point(other_id))
            check(screen.carrying and store.xp == previous_xp, "A wrong recipient cannot receive the tray")
        await click(guest_point(request_id))
        await create_timer(0.6).timeout
        await frames()
        check(store.xp > previous_xp and store.shift.served == recipe_index + 1, "Customer handoff serves and awards XP exactly once")
    await button("CounterMenu")
    check(screen.menu.visible and not store.is_processing(), "Pause freezes the clock")
    await button("ResumeCounter")
    key(KEY_G)
    key(KEY_G, false)
    await frames()
    check(screen.preparation != null, "G selects a guest without a pointer")
    var bench: Control = screen.bench
    await touch_drag(bench.global_position + bench.food_rect.get_center(), bench.global_position + bench.plate_rect.get_center())
    check(screen.preparation.kind() == "hold", "Touch drag places the physical ingredient")
    key(KEY_SPACE)
    for _i in range(18): screen.preparation.tick(0.1)
    key(KEY_SPACE, false)
    await frames()
    check(screen.preparation.kind() == "stir", "Keyboard hold/release controls extraction")
    for i in range(8):
        var code: Key = KEY_LEFT if i % 2 == 0 else KEY_RIGHT
        key(code)
        key(code, false)
    await frames()
    check(screen.preparation.kind() == "pick", "Alternating keyboard strokes whisk milk")
    key(KEY_ENTER)
    key(KEY_ENTER, false)
    await frames()
    check(int(store.find_order(screen.order_id).get("crafted", {}).get("latte", 0)) == 1, "Keyboard placement finishes the crafted latte")
    await button("CounterMenu")
    await button("Rush")
    check(screen.menu._confirm.visible and store.shift.mode == "FREE", "Starting over requires confirmation")
    await button("CounterCancelReset")
    check(not screen.menu._confirm.visible and store.shift.mode == "FREE", "Cancel preserves the current shift")
    await button("Rush")
    await button("CounterConfirmReset")
    check(store.shift.mode == "RUSH" and not screen.menu.visible, "Confirmed Rush starts the actual clock")
    await button("CounterMenu")
    var stopped: float = store.shift.remaining
    await create_timer(0.25).timeout
    check(store.shift.remaining == stopped, "Paused Rush does not consume time")
    root.size = Vector2i(390,844)
    await frames(8)
    await button("OpenDesk")
    check(app.current.find_child("Search", true, false) != null, "Original trial menu and cart remain available")
    check(root.get_visible_rect().encloses(app.return_button.get_global_rect()), "Return button fits the phone Order Desk")
    await button("BackToCafe")
    check(app.current.has_method("select_guest") and app.current.menu.visible, "Mode round trip safely returns to café")
    check(root.content_scale_size == Vector2i(430,931), "Returning restores aspect-matched portrait scaling")
    app.queue_free()
    await frames(3)
    store.set_process(false)
    print("PASS" if failures.is_empty() else "FAIL", ": counter GUI / ", actions, " pointer events / ", failures.size(), " failures")
    for message in failures: push_error(message)
    quit(0 if failures.is_empty() else 1)
