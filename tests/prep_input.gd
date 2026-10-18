extends RefCounted
## Shared native mouse/touch/keyboard gestures for every recipe; timing stepped independently.
var tree: SceneTree
var actions: int = 0
var failures: Array[String] = []
var capture_prefix: String = ""
var realtime: bool = false
var keyboard_only: bool = false
func key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = pressed
    tree.root.push_input(event,true)
    actions += 1
func touch_pointer(at: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = at
    event.pressed = pressed
    tree.root.push_input(event,true)
    actions += 1
func capture(bench: Control, suffix: String) -> void:
    if capture_prefix.is_empty() or DisplayServer.get_name() == "headless": return
    bench._process(0)
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://work/screenshots")
    tree.root.get_texture().get_image().save_png("res://work/screenshots/"+capture_prefix+"-"+suffix+".png")
func frames(count: int = 4) -> void:
    for _i in range(count): await tree.process_frame
func wait_for_band(model: RefCounted) -> bool:
    # Observe the running gauge like a player. A wall-clock sleep can overshoot
    # when rendering stalls, even though the simulation has not advanced equally.
    var deadline: int = Time.get_ticks_msec()+6000
    while model.progress < 0.81 and (model.holding or model.running) and Time.get_ticks_msec() < deadline:
        await tree.process_frame
    return model.progress >= 0.65 and model.progress <= 1.05
func pointer(at: Vector2, down: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = at
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = down
    tree.root.push_input(event,true)
    actions += 1
func click(at: Vector2) -> void:
    pointer(at,true)
    pointer(at,false)
    await frames()
func drag(a: Vector2, b: Vector2, touch: bool = false) -> void:
    if touch:
        var press := InputEventScreenTouch.new()
        press.index = 0
        press.position = a
        press.pressed = true
        tree.root.push_input(press,true)
        var motion := InputEventScreenDrag.new()
        motion.index = 0
        motion.position = b
        motion.relative = b-a
        tree.root.push_input(motion,true)
        press = InputEventScreenTouch.new()
        press.index = 0
        press.position = b
        tree.root.push_input(press,true)
    else:
        pointer(a,true)
        var motion := InputEventMouseMotion.new()
        motion.position = b
        motion.relative = b-a
        tree.root.push_input(motion,true)
        pointer(b,false)
    await frames()
func cook(station: Control, touch: bool = false) -> bool:
    station.bench.set_process(realtime)
    var iterations: int = 0
    while station.visible and station.finish.disabled and iterations < 100:
        await frames()
        var model: RefCounted = station.preparation
        if model == null:
            iterations += 1
            continue
        var bench: Control = station.bench
        bench._process(0)
        var ancestor: Node = bench.get_parent()
        while ancestor != null:
            if ancestor is ScrollContainer: ancestor.ensure_control_visible(bench)
            ancestor = ancestor.get_parent()
        await frames(2)
        var at: Vector2 = bench.global_position
        var before: int = model.index
        if keyboard_only:
            var kind: String = model.kind()
            if kind == "stir":
                for i in range(8):
                    key(KEY_LEFT if i%2 == 0 else KEY_RIGHT,true)
                    key(KEY_LEFT if i%2 == 0 else KEY_RIGHT,false)
            else:
                var code: Key = KEY_ENTER if kind in ["plate","cut"] else KEY_SPACE
                key(code,true)
                if kind == "hold": model.tick(1.72)
                key(code,false)
                if kind == "heat":
                    model.tick(2.85)
                    key(KEY_SPACE,true)
                    key(KEY_SPACE,false)
            await frames()
            if model.index == before and kind != "stack":
                failures.append("Keyboard action did not advance "+model.product+" / "+kind)
                station.bench.set_process(true)
                return false
            iterations += 1
            continue
        match model.kind():
            "pick", "plate": await drag(at+bench.food_rect.get_center(),at+bench.plate_rect.get_center(),touch)
            "stack":
                var index: int = mini(model.count,2)
                await drag(at+bench.sources[index].get_center(),at+bench.primary_rect.position+bench.primary_rect.size*Vector2(0.5,0.8),touch)
            "hold":
                if touch: touch_pointer(at+bench.primary_rect.get_center(),true)
                else: pointer(at+bench.primary_rect.get_center(),true)
                if realtime: await wait_for_band(model)
                else: model.tick(1.72)
                await capture(bench,"pour")
                if touch: touch_pointer(at+bench.primary_rect.get_center(),false)
                else: pointer(at+bench.primary_rect.get_center(),false)
                await frames()
            "heat":
                if touch:
                    touch_pointer(at+bench.primary_rect.get_center(),true)
                    touch_pointer(at+bench.primary_rect.get_center(),false)
                    await frames()
                else: await click(at+bench.primary_rect.get_center())
                if realtime: await wait_for_band(model)
                else: model.tick(2.85)
                await capture(bench,"heat")
                if touch:
                    touch_pointer(at+bench.primary_rect.get_center(),true)
                    touch_pointer(at+bench.primary_rect.get_center(),false)
                    await frames()
                else: await click(at+bench.primary_rect.get_center())
            "cut": await drag(at+bench.primary_rect.position+bench.primary_rect.size*Vector2(0.5,0.1),at+bench.primary_rect.position+bench.primary_rect.size*Vector2(0.5,0.9),touch)
            "stir":
                var centre: Vector2 = at+bench.primary_rect.get_center()
                if touch: touch_pointer(centre,true)
                else: pointer(centre,true)
                for i in range(10):
                    if touch:
                        var motion := InputEventScreenDrag.new()
                        motion.index = 0
                        motion.position = centre+Vector2(-40 if i%2 == 0 else 40,0)
                        motion.relative = Vector2(-80 if i%2 == 0 else 80,0)
                        tree.root.push_input(motion,true)
                    else:
                        var motion := InputEventMouseMotion.new()
                        motion.position = centre+Vector2(-40 if i%2 == 0 else 40,0)
                        motion.relative = Vector2(-80 if i%2 == 0 else 80,0)
                        tree.root.push_input(motion,true)
                if touch: touch_pointer(centre,false)
                else: pointer(centre,false)
                await frames()
        if model.index == before and model.kind() not in ["stack"]:
            failures.append("Physical action did not advance " + model.product+" / "+model.kind())
            station.bench.set_process(true)
            return false
        iterations += 1
    station.bench.set_process(true)
    return station.visible and not station.finish.disabled
