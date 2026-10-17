extends RefCounted
## Shared native mouse/touch/keyboard gestures for every recipe; timing stepped independently.
var tree: SceneTree
var actions: int = 0
var failures: Array[String] = []
func frames(count: int = 4) -> void:
    for _i in range(count): await tree.process_frame
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
    station.bench.set_process(false)
    var iterations: int = 0
    while station.visible and station.finish.disabled and iterations < 100:
        await frames()
        var model: RefCounted = station.preparation
        if model == null:
            iterations += 1
            continue
        var bench: Control = station.bench
        bench._process(0)
        var at: Vector2 = bench.global_position
        var before: int = model.index
        match model.kind():
            "pick", "plate": await drag(at+bench.food_rect.get_center(),at+bench.plate_rect.get_center(),touch)
            "stack":
                var index: int = mini(model.count,2)
                await drag(at+bench.sources[index].get_center(),at+bench.primary_rect.position+bench.primary_rect.size*Vector2(0.5,0.8),touch)
            "hold":
                pointer(at+bench.primary_rect.get_center(),true)
                model.tick(1.72)
                pointer(at+bench.primary_rect.get_center(),false)
                await frames()
            "heat":
                await click(at+bench.primary_rect.get_center())
                model.tick(2.85)
                await click(at+bench.primary_rect.get_center())
            "cut": await drag(at+bench.primary_rect.position+bench.primary_rect.size*Vector2(0.5,0.1),at+bench.primary_rect.position+bench.primary_rect.size*Vector2(0.5,0.9),touch)
            "stir":
                var centre: Vector2 = at+bench.primary_rect.get_center()
                pointer(centre,true)
                for i in range(10):
                    var motion := InputEventMouseMotion.new()
                    motion.position = centre+Vector2(-40 if i%2 == 0 else 40,0)
                    motion.relative = Vector2(-80 if i%2 == 0 else 80,0)
                    tree.root.push_input(motion,true)
                pointer(centre,false)
                await frames()
        if model.index == before and model.kind() not in ["stack"]:
            failures.append("Physical action did not advance " + model.product+" / "+model.kind())
            station.bench.set_process(true)
            return false
        iterations += 1
    station.bench.set_process(true)
    return station.visible and not station.finish.disabled
