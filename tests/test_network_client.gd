extends SceneTree
## Launch twice as separate Godot processes. No shared model or ticket state.
var handoff_path: String
var sync: Node
var client_role: String = "POS"
var finished: bool = false
var order_id: int = -1
var seen_new: bool = false
var seen_preparing: bool = false
var started: int
var debug_clock: float = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.get_node("OrderStore").persistence_enabled = false
    client_role = "KITCHEN" if "KITCHEN" in OS.get_cmdline_user_args() else "POS"
    started = Time.get_ticks_msec()
    handoff_path = OS.get_environment("CAFE_TEST_HANDOFF")
    sync = root.get_node("KitchenSync")
    sync.configure(OS.get_environment("CAFE_SYNC_ENDPOINT") if OS.has_environment("CAFE_SYNC_ENDPOINT") else "http://127.0.0.1:8790")
    sync.changed.connect(_on_changed)
    sync.order_sent.connect(func(id: int): order_id = id)
    print("Starting independent "+client_role+" client")
    if client_role == "POS":
        await sync.create_room()
        print("POS created room in %d ms" % (Time.get_ticks_msec()-started))
        if not sync.active:
            fail("Could not create room: "+sync.status)
            return
        var file := FileAccess.open(handoff_path+".tmp",FileAccess.WRITE)
        if file == null:
            fail("Could not open the private test handoff.")
            return
        file.store_string(JSON.stringify({"code":sync.kitchen_code}))
        file.close()
        var renamed: Error = DirAccess.rename_absolute(handoff_path+".tmp",handoff_path)
        if renamed != OK:
            fail("Could not write the private test handoff.")
            return
        await sync.submit({"latte":2,"chai":1},"Independent client A","7")
        if order_id < 0:
            fail("POS submission was not acknowledged")
    else:
        await sync.join_room(OS.get_environment("CAFE_TEST_KITCHEN_CODE"))
        if not sync.active:
            fail("Kitchen join failed: "+sync.status)

func _on_changed() -> void:
    if finished or not sync.active or sync.orders.is_empty():
        return
    var ticket: Dictionary = sync.orders[0]
    if int(ticket["total"]) != 470:
        fail("Server total is incorrect")
        return
    var status: String = str(ticket["status"])
    if client_role == "KITCHEN":
        if status == "NEW" and not seen_new:
            seen_new = true
            print("Kitchen process automatically received NEW ticket; total Rs 470")
            call_deferred("_advance",int(ticket["id"]),"NEW")
        elif status == "PREPARING" and not seen_preparing:
            seen_preparing = true
            print("Kitchen process received PREPARING status")
            call_deferred("_advance",int(ticket["id"]),"PREPARING")
        elif status == "DONE":
            if not seen_new or not seen_preparing:
                fail("Kitchen skipped a status")
                return
            finished = true
            print("PASS: independent kitchen process completed its ticket")
            sync.disconnect_room()
            quit(0)
    elif status == "DONE":
        finished = true
        print("PASS: independent POS process automatically received DONE in %d ms" % (Time.get_ticks_msec()-started))
        call_deferred("_finish_pos")

func _advance(id: int, status: String) -> void:
    await sync.advance(id,status)

func _finish_pos() -> void:
    await sync._api("/api/rooms/"+sync.room,HTTPClient.METHOD_DELETE)
    sync.disconnect_room()
    quit(0)

func _process(_delta: float) -> bool:
    debug_clock += _delta
    if sync != null and debug_clock >= 5:
        debug_clock = 0
        print("Network test %s: active=%s busy=%s polling=%s" % [client_role,sync.active,sync.busy,sync._polling])
    if sync != null and not finished and Time.get_ticks_msec()-started > 90000:
        fail("Automatic synchronization timed out")
    return false

func fail(message: String) -> void:
    finished = true
    push_error("FAIL: "+message)
    quit(1)
