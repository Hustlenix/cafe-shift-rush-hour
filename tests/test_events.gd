extends SceneTree
const Shift = preload("res://scripts/shift_rules.gd")
const Events = preload("res://scripts/rush_events.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, text: String) -> void:
    checks += 1
    if not value: failures.append(text)
func reward(personality: String, quality: int, pours: int, age: float, event: String) -> int:
    var run := Shift.new()
    run.start("RUSH",7)
    run.requests.clear()
    var id: String = run.welcome(personality)
    run.elapsed = age
    run.events.active_id = event
    run.sent(id,101)
    return 25+quality+run.completed(101,quality,pours)
func _run() -> void:
    for entry in Events.DATA:
        var run := Shift.new()
        run.start("RUSH",77)
        run.tick(float(entry["at"])-6)
        check(run.events.active_id == "" and run.events.notice.contains("6s"),"Rules preview before "+str(entry["id"]))
        run.requests.clear()
        run.tick(6)
        check(run.events.active_id == entry["id"],"Activates "+str(entry["id"]))
        if entry["id"] == "LUNCH": check(run.arrival_interval() == 4,"Lunch changes arrival rate")
        if entry["id"] == "VIP":
            var vip: bool = false
            for request in run.requests: vip = vip or request["personality"] == "VIP"
            check(vip,"VIP arrives as an actual guest")
        var restored := Shift.new()
        restored.restore(JSON.parse_string(JSON.stringify(run.snapshot())))
        check(restored.events.active_id == run.events.active_id and restored.events.ends == run.events.ends,"Active event survives save")
        run.tick(float(entry["duration"]))
        check(run.events.active_id == "" and not run.events.vip_pending,"Event expires "+str(entry["id"]))
    var events := Events.new()
    var transitions: Array[String] = []
    for second in range(181):
        events.tick(float(second))
        if events.active_id != "" and events.active_id not in transitions: transitions.append(events.active_id)
        var eligible: int = 0
        for entry in Events.DATA:
            if second >= entry["at"] and second < entry["at"]+entry["duration"]: eligible += 1
        check(eligible <= 1,"No event overlaps at second "+str(second))
    check(transitions == ["LUNCH","VIP","PERFECT"],"All three events fit a three-minute shift")
    check(reward("Regular",20,1,10,"PERFECT") == 2*reward("Regular",20,1,10,""),"Perfect fast service doubles total XP")
    check(reward("Regular",20,0,10,"PERFECT") == reward("Regular",20,0,10,""),"Challenge requires a perfect pour")
    check(reward("Regular",10,1,10,"PERFECT") == reward("Regular",10,1,10,""),"Low quality cannot claim challenge")
    check(reward("Regular",20,1,36,"PERFECT") == reward("Regular",20,1,36,""),"Late service cannot claim challenge")
    check(reward("VIP",20,1,10,"PERFECT") == reward("VIP",20,1,10,""),"VIP and challenge multipliers cannot stack")
    var store: Node = root.get_node("OrderStore")
    store.persistence_enabled = false
    store.start_shift("RUSH",55)
    store.shift.tick(102)
    store.shift.tick(26)
    check(not store.shift.events.vip_pending,"VIP cannot arrive after expiry")
    store.start_shift("RUSH",55)
    store.shift.tick(180)
    check(store.shift.result == "TIMEOUT" and store.shift.events.active_id == "","Timeout clears events")
    store.start_shift("FREE",55)
    store.shift.events.tick(64)
    store._process(400)
    check(store.shift.elapsed == 0,"Practice never advances event time")
    store.gameplay_running = false
    print("PASS" if failures.is_empty() else "FAIL",": ",checks," event checks / ",failures.size()," failures")
    for failure in failures: push_error(failure)
    quit(0 if failures.is_empty() else 1)
