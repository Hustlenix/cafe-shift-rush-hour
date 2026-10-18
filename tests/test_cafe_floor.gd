extends SceneTree
## Real scene regression: counter placement, facing, crisp scaling and picking.
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func frames(count: int = 6) -> void:
    for _i in range(count): await process_frame
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func _run() -> void:
    var store: Node = root.get_node("OrderStore")
    store.persistence_enabled = false
    root.min_size = Vector2i.ZERO
    root.size = Vector2i(1440,900)
    var app: Control = load("res://scenes/main.tscn").instantiate()
    root.add_child(app)
    await frames(12)
    for resolution in [Vector2i(1440,900),Vector2i(390,844)]:
        root.size = resolution
        store.start_shift("FREE",0)
        store.shift.welcome()
        store.shift.welcome()
        app.flow.playing("FREE")
        store.gameplay_running = false
        await frames(10)
        var world: Control = app._world
        world.set_process(false)
        world.actors.clear()
        world._process(1.0/60.0)
        check(world.actors.size() == 3,"Three real customers enter the scene")
        check(world.actors["R1"]["moving"] and world.actors["R1"]["facing"] == "left","Arrival faces its direction of travel")
        world._process(8)
        world._process(0)
        var zoom: Vector2 = world.room_zoom()
        var origin: Vector2 = world.room_origin(zoom)
        var pixel_transform: Transform2D = root.get_stretch_transform()*world.get_global_transform_with_canvas()
        var physical: Vector2 = zoom * pixel_transform.get_scale()
        check(physical.is_equal_approx(physical.round()),"Whole physical pixels at "+str(resolution))
        check((origin+world.ROOM_SIZE*zoom).x <= world.size.x+1 and origin.y >= -1,"Entire cafe fits the view")
        var screen_origin: Vector2 = pixel_transform*origin
        check(screen_origin.distance_to(screen_origin.round()) < 0.01,"Pixel-aligned origin")
        var aisle := Rect2(112,114,128,16)
        for id in world.actors:
            var actor: Dictionary = world.actors[id]
            var feet: Vector2 = actor["pos"]+Vector2(8,28)
            check(aisle.has_point(feet),"Customer stands in the clear counter aisle: "+id)
            check(not actor["moving"] and actor["facing"] == ("left" if id == "R3" else "up"),"Waiting guest faces the cashier: "+id)
            var target: Vector2 = origin+((actor["pos"] as Vector2).round()+Vector2(8,16))*zoom
            check(world._actor_at(target) == id,"Picking matches the displayed customer: "+id)
        world.set_selected_request("R1")
        world.queue_redraw()
        await frames()
        print("Cafe ",resolution," logical view=",world.size," physical pixel size=",physical)
        if DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://work/screenshots")
            root.get_texture().get_image().save_png("res://work/screenshots/cafe-counter-%d.png" % resolution.x)
        store.shift.requests[0]["state"] = "KITCHEN"
        world._process(0)
        check(world.actors["R1"]["facing"] == "up","Submitted guest still faces service counter")
        store.shift.requests.remove_at(0)
        world._process(1.0/60.0)
        check(world.actors["R1"]["state"] == "LEAVING" and world.actors["R1"]["facing"] == "right","Departure faces the exit")
        world.reduced_motion = true
        world._process(0)
        world._process(0)
        check(not world.actors.has("R1") and not world.actors["R2"]["moving"] and world.actors["R2"]["facing"] == "up","Reduced motion settles facing the cashier")
        world.reduced_motion = false
    app.queue_free()
    await frames()
    print("PASS" if failures.is_empty() else "FAIL",": ",checks," cafe floor checks / ",failures.size()," failures")
    for failure in failures: push_error(failure)
    quit(0 if failures.is_empty() else 1)
