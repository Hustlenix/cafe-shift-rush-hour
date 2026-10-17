extends Node
## Independent HTTPS client; local loopback HTTP is permitted for development.
## No room tokens are embedded in the export or placed in URLs.

signal changed
signal order_sent(order_id: int)
const DEFAULT_ENDPOINT: String = "https://cafe-shift-rush-hour.vercel.app"
var endpoint: String = DEFAULT_ENDPOINT
var room: String = ""
var token: String = ""
var role: String = ""
var kitchen_code: String = ""
var orders: Array[Dictionary] = []
var status: String = "Offline · saved on this device"
var active: bool = false
var busy: bool = false
var _polling: bool = false
var _clock: float = 0
var _backoff: float = 2
var _generation: int = 0
var _pending_nonce: String = ""
var _pending_body: String = ""
var _request: HTTPRequest
var polling_suspended: bool = false

func _process(delta: float) -> void:
    if not active or busy or _polling or polling_suspended:
        return
    _clock += delta
    if _clock >= _backoff:
        _clock = 0
        poll()

func configure(value: String) -> bool:
    var candidate: String = value.strip_edges().trim_suffix("/")
    if not candidate.begins_with("https://") and candidate not in ["http://127.0.0.1:8790", "http://localhost:8790"]:
        status = "Use HTTPS, or the supported local development server."
        changed.emit()
        return false
    if active or busy:
        return false
    endpoint = candidate
    return true

func _nonce() -> String:
    return Crypto.new().generate_random_bytes(16).hex_encode()

func _api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}) -> Dictionary:
    var generation: int = _generation
    var req := HTTPRequest.new()
    req.timeout = 12
    _request = req
    add_child(req)
    var headers: PackedStringArray = ["Content-Type: application/json"]
    if not token.is_empty():
        headers.append("Authorization: Bearer "+token)
    var error: Error = req.request(endpoint+path,headers,method,JSON.stringify(payload) if not payload.is_empty() else "")
    if error != OK:
        req.queue_free()
        return {"ok":false,"error":"Could not start the network request."}
    var result: Array = await req.request_completed
    req.queue_free()
    if generation != _generation:
        return {"ok":false,"cancelled":true,"error":"Connection closed."}
    if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
        return {"ok":false,"error":"Connection interrupted. Your cart is safe; retry when connected."}
    var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
    var response: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
    response["ok"] = int(result[1]) >= 200 and int(result[1]) < 300
    response["http_status"] = int(result[1])
    if not response["ok"] and not response.has("error"):
        response["error"] = "Service is not ready. Offline play is available."
    return response

func _path() -> String:
    return "/api/rooms/"+room+"/orders"

func create_room() -> void:
    if busy or active:
        return
    busy = true
    status = "Creating a private room…"
    changed.emit()
    var response: Dictionary = await _api("/api/rooms",HTTPClient.METHOD_POST)
    busy = false
    if response.get("cancelled",false): return
    if not response.get("ok",false):
        status = str(response.get("error","Service unavailable."))
        changed.emit()
        return
    room = str(response.get("room",""))
    token = str(response.get("token",""))
    kitchen_code = str(response.get("kitchen_code",""))
    role = "POS"
    active = true
    polling_suspended = false
    _backoff = 2
    await poll()

func join_room(code: String) -> void:
    if busy or active:
        return
    var parts: PackedStringArray = code.strip_edges().split(".")
    var pattern := RegEx.new()
    pattern.compile("^[a-f0-9]{48}$")
    if parts.size() != 2 or pattern.search(parts[0]) == null or pattern.search(parts[1]) == null:
        status = "Paste the complete kitchen code from the till."
        changed.emit()
        return
    busy = true
    room = parts[0]
    token = parts[1]
    status = "Joining kitchen…"
    changed.emit()
    var response: Dictionary = await _api(_path())
    busy = false
    if response.get("cancelled",false): return
    if not response.get("ok",false) or str(response.get("role","")) != "KITCHEN":
        token = ""
        room = ""
        status = str(response.get("error","This is not a kitchen credential."))
        changed.emit()
        return
    role = "KITCHEN"
    active = true
    polling_suspended = false
    _apply(response)

func poll() -> void:
    if not active or _polling or busy:
        return
    _polling = true
    var response: Dictionary = await _api(_path())
    _polling = false
    if not active or response.get("cancelled",false):
        return
    if response.get("ok",false):
        _apply(response)
        _backoff = 2
    else:
        _backoff = minf(20,_backoff*2)
        _failure(response)
        changed.emit()

func _failure(response: Dictionary) -> void:
    polling_suspended = int(response.get("http_status",0)) in [401,403,404,410]
    status = "Room code invalid or expired. Disconnect, then create or join a room." if polling_suspended else str(response.get("error","Reconnecting…")) + " · retrying automatically"

func retry_now() -> void:
    if busy or _polling or not active: return
    if not _pending_body.is_empty():
        var payload: Dictionary = JSON.parse_string(_pending_body)
        var cart: Dictionary = {}
        for line in payload["items"]: cart[str(line["id"])] = int(line["qty"])
        submit(cart,str(payload["customer"]),str(payload["table"]))
    elif not polling_suspended:
        poll()

func has_pending_order() -> bool:
    return not _pending_body.is_empty()

func _apply(response: Dictionary) -> void:
    var updated: Array[Dictionary] = []
    if typeof(response.get("orders")) == TYPE_ARRAY:
        for candidate in response["orders"]:
            if typeof(candidate) == TYPE_DICTIONARY and typeof(candidate.get("items")) == TYPE_ARRAY and str(candidate.get("status","")) in ["NEW","PREPARING","DONE"]:
                updated.append(candidate)
    var new_status: String = "Connected · %s · auto refresh every 2s" % role
    if has_pending_order(): new_status += " · ticket awaiting Retry"
    if orders != updated or status != new_status:
        orders = updated
        status = new_status
        changed.emit()

func submit(cart: Dictionary, customer: String, table: String) -> void:
    if not active or busy:
        status = "Wait for the connection to finish, then retry."
        changed.emit()
        return
    if role != "POS":
        status = "Only the till can send tickets to the kitchen."
        changed.emit()
        return
    var lines: Array[Dictionary] = []
    var ids: Array = cart.keys()
    ids.sort()
    for id in ids:
        lines.append({"id":str(id),"qty":int(cart[id])})
    var fingerprint: String = JSON.stringify({"items":lines,"customer":customer,"table":table})
    if not _pending_body.is_empty() and fingerprint != _pending_body:
        status = "The previous ticket needs confirmation. Use Retry before sending another order."
        changed.emit()
        return
    if fingerprint != _pending_body:
        _pending_body = fingerprint
        _pending_nonce = _nonce()
    busy = true
    while _polling:
        await get_tree().process_frame
    if not active:
        busy = false
        return
    status = "Sending ticket…"
    changed.emit()
    var response: Dictionary = await _api(_path(),HTTPClient.METHOD_POST,{"nonce":_pending_nonce,"items":lines,"customer":customer,"table":table})
    busy = false
    if response.get("cancelled",false): return
    if response.get("ok",false):
        _pending_body = ""
        _pending_nonce = ""
        order_sent.emit(int(response["order"]["id"]))
        await poll()
    else:
        if int(response.get("http_status",0)) in [400,409,413,422,429]:
            _pending_body = ""
            _pending_nonce = ""
        _failure(response)
        if has_pending_order(): status += " · Retry checks the SAME ticket; your cart is safe."
        changed.emit()

func advance(id: int, expected_status: String) -> void:
    if not active or role != "KITCHEN" or busy:
        return
    busy = true
    while _polling:
        await get_tree().process_frame
    if not active:
        busy = false
        return
    status = "Updating kitchen ticket…"
    changed.emit()
    var response: Dictionary = await _api(_path()+"/"+str(id),HTTPClient.METHOD_PATCH,{"expected_status":expected_status})
    busy = false
    if response.get("cancelled",false): return
    if not response.get("ok",false):
        if int(response.get("http_status",0)) == 409:
            await poll()
            return
        _failure(response)
        changed.emit()
        return
    await poll()

func disconnect_room() -> void:
    _generation += 1
    active = false
    polling_suspended = false
    role = ""
    room = ""
    token = ""
    kitchen_code = ""
    orders.clear()
    status = "Offline · saved on this device"
    _pending_nonce = ""
    _pending_body = ""
    changed.emit()
