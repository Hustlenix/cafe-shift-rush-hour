extends RefCounted
## One modifier at a time, with six seconds of warning and fixed expiry.
const DATA: Array[Dictionary] = [
    {"id":"LUNCH","at":64.0,"duration":20.0,"title":"LUNCH RUSH","rule":"Arrivals every 4 seconds. Watch patience."},
    {"id":"VIP","at":102.0,"duration":25.0,"title":"VIP VISIT","rule":"A larger order. Excellent service earns double."},
    {"id":"PERFECT","at":142.0,"duration":24.0,"title":"PERFECT SERVICE","rule":"Perfect pour + 80% quality + service under 35s: double XP."}
]
var active_id: String = ""
var notice: String = ""
var ends: float = 0
var seen: Array[String] = []
var vip_pending: bool = false
func reset() -> void:
    active_id = ""
    notice = ""
    ends = 0
    seen.clear()
    vip_pending = false
func stop() -> void:
    active_id = ""
    notice = ""
    vip_pending = false
func tick(elapsed: float) -> bool:
    var before: String = active_id + notice
    if not active_id.is_empty() and elapsed >= ends: stop()
    if active_id.is_empty(): notice = ""
    for event in DATA:
        var at: float = event["at"]
        var id: String = event["id"]
        if id in seen or not active_id.is_empty(): continue
        if elapsed >= at-6 and elapsed < at:
            notice = "%s in %ds · %s" % [event["title"],ceili(at-elapsed),event["rule"]]
        if elapsed >= at and elapsed < at+float(event["duration"]):
            active_id = id
            ends = at+float(event["duration"])
            notice = str(event["title"])+" · "+str(event["rule"])
            seen.append(id)
            vip_pending = id == "VIP"
    return before != active_id+notice
func snapshot() -> Dictionary:
    return {"id":active_id,"notice":notice,"ends":ends,"seen":seen.duplicate(),"vip_pending":vip_pending}
func restore(data: Dictionary) -> void:
    reset()
    for event in DATA:
        if str(data.get("id","")) == event["id"]:
            active_id = str(event["id"])
            ends = float(event["at"])+float(event["duration"])
        if typeof(data.get("seen")) == TYPE_ARRAY and event["id"] in data["seen"]: seen.append(str(event["id"]))
    notice = str(data.get("notice","")).left(180)
    vip_pending = active_id == "VIP" and data.get("vip_pending",false) == true
