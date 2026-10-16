extends SceneTree
## End-to-end reliability test for KitchenSync against the real local kitchen
## server (backend/local-server.mjs). Spawns and kills the server mid-run to
## prove graceful degradation, retry-key reuse, recovery and room revocation.
## Run from the project root: godot --headless --path . --script res://tests/test_sync.gd
## Requires node on PATH and nothing else listening on 127.0.0.1:8790.
const ENDPOINT: String = "http://127.0.0.1:8790"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures.append(description)

func _health() -> bool:
    var req: HTTPRequest = HTTPRequest.new()
    root.add_child(req)
    var error: Error = req.request(ENDPOINT+"/api/health")
    if error != OK:
        req.queue_free()
        return false
    var result: Array = await req.request_completed
    req.queue_free()
    return int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200

func _wait_health(tries: int) -> bool:
    for _i in range(tries):
        if await _health():
            return true
        await create_timer(0.25).timeout
    return false

func _spawn_server() -> int:
    var arguments: PackedStringArray = ["backend/local-server.mjs"]
    return OS.create_process("node",arguments)

func _revoke(room_id: String, token: String) -> bool:
    var req: HTTPRequest = HTTPRequest.new()
    root.add_child(req)
    var headers: PackedStringArray = ["Authorization: Bearer "+token]
    var error: Error = req.request(ENDPOINT+"/api/rooms/"+room_id,headers,HTTPClient.METHOD_DELETE)
    if error != OK:
        req.queue_free()
        return false
    var result: Array = await req.request_completed
    req.queue_free()
    return int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200

func _run() -> void:
    var pid: int = _spawn_server()
    check(pid > 0,"Local kitchen server spawns")
    var up: bool = await _wait_health(40)
    check(up,"Local kitchen server answers health checks")

    var pos: Node = load("res://scripts/kitchen_sync.gd").new()
    root.add_child(pos)
    check(not pos.configure("http://192.168.1.10"),"Plain HTTP to a LAN host is refused")
    check(pos.configure(ENDPOINT),"Loopback development endpoint accepted")
    check(not pos.active,"Clients start offline")
    check(pos.endpoint == ENDPOINT,"Endpoint switch keeps the loopback target")

    await pos.create_room()
    check(pos.active and pos.role == "POS","Till creates a room")
    check(pos.kitchen_code.length() == 97 and pos.kitchen_code.count(".") == 1,"Kitchen code pairs the room and kitchen credentials")
    var saved_room: String = pos.room
    var saved_token: String = pos.token
    var saved_code: String = pos.kitchen_code

    var kit: Node = load("res://scripts/kitchen_sync.gd").new()
    root.add_child(kit)
    kit.configure(ENDPOINT)
    await kit.join_room("not-a-real-code")
    check(not kit.active and kit.status.contains("complete kitchen code"),"Malformed kitchen codes are rejected locally")
    await kit.join_room("f".repeat(48)+"."+"e".repeat(48))
    check(not kit.active and kit.status.contains("expired room code"),"Unknown credentials are rejected by the server")
    await kit.join_room(saved_code)
    check(kit.active and kit.role == "KITCHEN","Kitchen joins with the till's code")

    var sent: Array[int] = []
    pos.order_sent.connect(func(order_id: int) -> void: sent.append(order_id))
    await pos.submit({"latte":2,"chai":1},"Test Guest","7")
    check(sent.size() == 1 and pos.orders.size() == 1,"Till sends a ticket and sees it in the room")
    check(int(pos.orders[0]["total"]) == 470,"Server prices the ticket from its own menu")

    await kit.poll()
    check(kit.orders.size() == 1 and str(kit.orders[0]["status"]) == "NEW","Kitchen receives the new ticket")
    var ticket_id: int = int(kit.orders[0]["id"])

    await kit.submit({"cookie":1},"Test Guest","7")
    check(kit.status.contains("Only the till"),"Kitchen submissions are refused with a clear message")
    await pos.poll()
    check(pos.orders.size() == 1,"Refused kitchen submission creates no ticket")

    await kit.advance(ticket_id,"NEW")
    check(str(kit.orders[0]["status"]) == "PREPARING","Kitchen starts the ticket")
    await kit.advance(ticket_id,"PREPARING")
    check(str(kit.orders[0]["status"]) == "DONE","Kitchen finishes the ticket")
    await kit.advance(ticket_id,"PREPARING")
    check(kit.status.contains("already changed"),"A stale transition asks the kitchen to refresh")
    check(str(kit.orders[0]["status"]) == "DONE","A stale transition leaves the known status intact")
    await create_timer(2.4).timeout
    check(kit.status.contains("Connected"),"Kitchen returns to the auto-refresh cycle after a stale transition")

    await pos.poll()
    check(str(pos.orders[0]["status"]) == "DONE","Till refreshes to DONE through polling")

    OS.kill(pid)
    await create_timer(0.8).timeout
    await pos.poll()
    check(pos.active,"A failed poll keeps the connection armed")
    check(pos.status.contains("retrying automatically"),"A failed poll reports automatic retries")
    check(pos._backoff > 2.0,"Poll failures back off")

    await pos.submit({"cookie":1},"Test Guest","7")
    check(not pos._pending_nonce.is_empty(),"A failed submit keeps its retry key")
    check(pos.status.contains("retry when connected"),"A failed submit explains the safe retry")
    var kept_nonce: String = pos._pending_nonce

    var cold: Node = load("res://scripts/kitchen_sync.gd").new()
    root.add_child(cold)
    cold.configure(ENDPOINT)
    await cold.create_room()
    check(not cold.active and cold.status.contains("retry when connected"),"Offline room creation fails gracefully")

    var pid2: int = _spawn_server()
    check(pid2 > 0,"Local kitchen server restarts")
    var up2: bool = await _wait_health(40)
    check(up2,"Restarted server answers health checks")

    await pos.submit({"cookie":1},"Test Guest","7")
    check(pos._pending_nonce.is_empty(),"A successful retry clears the retry key")
    check(sent.size() == 2,"The till is told when the retried ticket lands")
    check(pos.orders.size() == 2,"The retried ticket lands once after recovery")
    check(str(pos.orders[0].get("nonce","")) == kept_nonce,"The retry reuses the original request key")

    var pos2: Node = load("res://scripts/kitchen_sync.gd").new()
    root.add_child(pos2)
    pos2.configure(ENDPOINT)
    await pos2.join_room(saved_code)
    check(pos2.active and pos2.role == "KITCHEN","A fresh client can still join after the outage")

    pos.disconnect_room()
    check(not pos.active and pos.orders.is_empty() and pos.status.contains("Offline"),"Disconnect returns the till to offline mode")

    var revoked: bool = await _revoke(saved_room,saved_token)
    check(revoked,"Temporary test room is revoked")

    OS.kill(pid2)
    for node in [pos,kit,cold,pos2]:
        node.queue_free()
    await create_timer(0.1).timeout
    for message in failures:
        push_error("FAIL: "+message)
    print("%s: kitchen sync, %d end-to-end checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
