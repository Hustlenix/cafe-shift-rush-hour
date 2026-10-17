extends SceneTree
const Shift = preload("res://scripts/shift_rules.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func _run() -> void:
    for seed_value in range(1,41):
        var a := Shift.new()
        var b := Shift.new()
        a.start("RUSH",seed_value)
        b.start("RUSH",seed_value)
        var types: Array[String] = []
        var recent: Array[String] = []
        for i in range(14):
            a.requests.clear()
            b.requests.clear()
            a.elapsed = 10*i
            b.elapsed = a.elapsed
            a.welcome()
            b.welcome()
            check(a.requests == b.requests,"Deterministic sequence")
            var request: Dictionary = a.requests[0]
            types.append(request["personality"])
            var total: int = 0
            for qty in request["recipe"].values(): total += int(qty)
            check(total >= 1 and total <= 3,"Bounded complexity")
            if request["personality"] == "Big Order": check(total == 3 and request["max_patience"] >= 135,"Big orders get enough time")
            if request["personality"] == "Impatient": check(total == 1,"Impatient orders stay simple")
            recent.append(JSON.stringify(request["recipe"]))
            if recent.size() >= 3: check(not (recent[-1] == recent[-2] and recent[-2] == recent[-3]),"No three identical consecutive orders")
        for personality in ["Regular","Impatient","Generous","Big Order"]: check(personality in types.slice(0,4),"Fair personality bag")
        var restored := Shift.new()
        restored.restore(JSON.parse_string(JSON.stringify(a.snapshot())))
        a.requests.clear()
        restored.requests.clear()
        a.welcome()
        restored.welcome()
        check(a.requests == restored.requests,"Save resumes RNG exactly")
    var run := Shift.new()
    run.start("RUSH",42)
    check(run.arrival_interval() == 18,"Gentle opening arrivals")
    run.elapsed = 60
    check(run.arrival_interval() == 14,"Middle phase builds pressure")
    run.elapsed = 120
    check(run.arrival_interval() == 10,"Final phase creates prioritization")
    run.start("FREE",42)
    run.served = 20
    run.tick(500)
    check(run.elapsed == 0 and run.phase() == 0,"Practice has no escalation")
    for personality in ["Regular","Impatient","Generous","VIP"]:
        run.start("RUSH",42)
        run.requests.clear()
        var id: String = run.welcome(personality)
        run.sent(id,101)
        var bonus: int = run.completed(101,20)
        check(bonus > (20 if personality == "Regular" else 30),"Personality changes actual reward")
        var score: int = run.score
        run.completed(101,20)
        check(run.score == score,"No repeated reward")
    print("PASS" if failures.is_empty() else "FAIL",": ",checks," customer checks / ",failures.size()," failures")
    for message in failures: push_error(message)
    quit(0 if failures.is_empty() else 1)
