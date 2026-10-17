extends RefCounted
## Pure run model. Presentation never writes patience, goal, or rewards.

const NAMES: Array[String] = ["Amelia", "Adam", "Alex", "Bob", "Lucy", "Ash"]
const RECIPES: Array[Dictionary] = [
    {"latte": 1, "croissant": 1}, {"chai": 2}, {"coldbrew": 1, "cookie": 1},
    {"matcha": 1, "brownie": 1}, {"espresso": 2, "toastie": 1}, {"latte": 1, "cookie": 2}
]
var mode: String = "FREE"
var active: bool = true
var remaining: float = 180.0
var elapsed: float = 0.0
var arrival_clock: float = 0.0
var sequence: int = 0
var served: int = 0
var missed: int = 0
var streak: int = 0
var score: int = 0
var result: String = ""
var tips_total: int = 0
var best_streak: int = 0
var left_out: String = ""  # transient: id of the guest who just ran out of patience
var requests: Array[Dictionary] = []
var generator := preload("res://scripts/customer_generator.gd").new()
var quality_total: int = 0
var satisfaction_total: int = 0
var perfect_pours: int = 0
var perfect_services: int = 0
var last_service: Dictionary = {}

func _init() -> void:
    generator.restart()

func phase() -> int:
    return 0 if mode == "FREE" else (2 if elapsed >= 120 else (1 if elapsed >= 60 else 0))

func start(value: String, seed_value: int = -1) -> void:
    generator.restart(seed_value)
    quality_total = 0
    satisfaction_total = 0
    perfect_pours = 0
    perfect_services = 0
    last_service.clear()
    mode = "RUSH" if value == "RUSH" else "FREE"
    active = true
    remaining = 180.0
    elapsed = 0.0
    arrival_clock = 0.0
    sequence = 0
    served = 0
    missed = 0
    streak = 0
    score = 0
    result = ""
    tips_total = 0
    best_streak = 0
    left_out = ""
    requests.clear()
    welcome()
    if mode == "RUSH":
        welcome()

func welcome(forced: String = "") -> String:
    if not active or requests.size() >= 3:
        return ""
    var index: int = sequence % RECIPES.size()
    var data: Dictionary = generator.next(phase(),sequence,mode == "FREE",forced)
    if generator.seed_value == 0:
        data = {"recipe":RECIPES[index].duplicate(),"personality":"Regular","remark":"The usual, please.","max_patience":65.0}
    sequence += 1
    var id: String = "R%d" % sequence
    requests.append({"id": id, "name": NAMES[index], "table": str(index + 1),
        "recipe": data["recipe"], "patience": data["max_patience"],"max_patience":data["max_patience"],
        "personality":data["personality"],"remark":data["remark"],
        "state": "WAITING", "order_id": -1, "arrived": elapsed})
    return id

func find_request(id: String) -> Dictionary:
    for request in requests:
        if str(request["id"]) == id:
            return request
    return {}

func matches(id: String, cart: Dictionary) -> bool:
    var request: Dictionary = find_request(id)
    return not request.is_empty() and str(request["state"]) == "WAITING" and cart == request["recipe"]

func sent(id: String, order_id: int) -> void:
    var request: Dictionary = find_request(id)
    if not request.is_empty():
        request["state"] = "KITCHEN"
        request["order_id"] = order_id

func completed(order_id: int, quality: int = 0, pours: int = 0) -> int:
    last_service.clear()
    for i in range(requests.size()):
        if int(requests[i]["order_id"]) == order_id:
            var bonus: int = 0
            if active:
                var tip: int = mini(20, maxi(0, int(float(requests[i]["patience"]) / 5.0)))
                var excellent: bool = quality >= 16 and float(requests[i]["patience"]) > 0
                var quick: bool = elapsed - float(requests[i].get("arrived",elapsed)) <= 35
                var personality: String = str(requests[i].get("personality","Regular"))
                if personality == "Impatient" and quick: tip += 12
                if personality == "Generous" and excellent: tip += 18
                streak = streak + 1 if float(requests[i]["patience"]) > 0 else 0
                bonus = tip + mini(15, streak * 3)
                var multiplier: int = 2 if personality == "VIP" and excellent else 1
                bonus += (25 + bonus + quality) * (multiplier-1)
                tips_total += tip
                best_streak = maxi(best_streak, streak)
                served += 1
                score += 25 + bonus + quality
                quality_total += clampi(quality,0,20)
                perfect_pours += maxi(0,pours)
                if excellent: perfect_services += 1
                var satisfaction: int = clampi(35 + quality*2 + int(25.0*float(requests[i]["patience"])/maxf(1,float(requests[i].get("max_patience",65)))),0,100)
                satisfaction_total += satisfaction
                last_service = {"quality":quality,"satisfaction":satisfaction,"multiplier":multiplier,"tip":tip,"personality":personality}
            requests.remove_at(i)
            if mode == "RUSH" and active and served >= 5:
                active = false
                result = "SUCCESS"
            elif mode == "FREE":
                welcome()
            return bonus
    return 0

func arrival_interval() -> float:
    # The rush builds: each served order tightens the arrival cadence (12s → 8s).
    return maxf(8.0, 12.0 - 0.8 * float(served)) if generator.seed_value == 0 else [18.0,14.0,10.0][phase()]

func tick(delta: float) -> bool:
    if not active or mode != "RUSH":
        return false
    elapsed += delta
    remaining = maxf(0.0, remaining - delta)
    arrival_clock += delta
    var changed: bool = false
    for i in range(requests.size() - 1, -1, -1):
        requests[i]["patience"] = maxf(0.0, float(requests[i]["patience"]) - delta)
        # Submitted kitchen tickets remain valid; late service loses the tip.
        if float(requests[i]["patience"]) <= 0 and str(requests[i]["state"]) == "WAITING":
            left_out = str(requests[i]["id"])
            requests.remove_at(i)
            missed += 1
            streak = 0
            changed = true
    if arrival_clock >= arrival_interval():
        arrival_clock = 0.0
        changed = not welcome().is_empty() or changed
    if remaining <= 0:
        active = false
        result = "TIMEOUT"
        changed = true
    return changed

func snapshot() -> Dictionary:
    return {"mode": mode, "active": active, "remaining": remaining, "elapsed": elapsed,
        "arrival_clock": arrival_clock, "sequence": sequence, "served": served,
        "missed": missed, "streak": streak, "score": score, "result": result,
        "tips_total": tips_total, "best_streak": best_streak, "requests": requests,
        "generator":generator.snapshot(),"quality_total":quality_total,"satisfaction_total":satisfaction_total,
        "perfect_pours":perfect_pours,"perfect_services":perfect_services}

func restore(data: Dictionary) -> void:
    if data.is_empty():
        start("FREE")
        return
    mode = "RUSH" if str(data.get("mode", "FREE")) == "RUSH" else "FREE"
    active = bool(data.get("active", true))
    remaining = clampf(float(data.get("remaining", 180.0)), 0, 180)
    elapsed = maxf(0, float(data.get("elapsed", 0)))
    arrival_clock = clampf(float(data.get("arrival_clock", 0)), 0, 18)
    sequence = maxi(0, int(data.get("sequence", 0)))
    served = maxi(0, int(data.get("served", 0)))
    missed = maxi(0, int(data.get("missed", 0)))
    streak = maxi(0, int(data.get("streak", 0)))
    score = maxi(0, int(data.get("score", 0)))
    result = str(data.get("result", ""))
    tips_total = maxi(0, int(data.get("tips_total", 0)))
    best_streak = maxi(0, int(data.get("best_streak", 0)))
    left_out = ""
    generator.restore(data.get("generator",{}))
    quality_total = maxi(0,int(data.get("quality_total",0)))
    satisfaction_total = maxi(0,int(data.get("satisfaction_total",0)))
    perfect_pours = maxi(0,int(data.get("perfect_pours",0)))
    perfect_services = maxi(0,int(data.get("perfect_services",0)))
    last_service.clear()
    requests.clear()
    if typeof(data.get("requests")) != TYPE_ARRAY:
        return
    for r in data["requests"]:
        if typeof(r) != TYPE_DICTIONARY or typeof(r.get("recipe")) != TYPE_DICTIONARY:
            continue
        if not r.has_all(["id", "name", "state", "order_id", "patience", "table"]):
            continue
        if str(r["state"]) not in ["WAITING", "KITCHEN"]:
            continue
        var valid: bool = true
        var recipe: Dictionary = {}
        for key in r["recipe"]:
            if key not in ["latte", "espresso", "coldbrew", "chai", "matcha", "croissant", "toastie", "brownie", "cookie"] or typeof(r["recipe"][key]) not in [TYPE_INT, TYPE_FLOAT] or int(r["recipe"][key]) < 1 or int(r["recipe"][key]) > 9:
                valid = false
            else:
                recipe[str(key)] = int(r["recipe"][key])
        if valid and requests.size() < 3:
            # JSON numbers are floats; recipe matching uses integer cart counts.
            r["recipe"] = recipe
            r["order_id"] = int(r["order_id"])
            r["max_patience"] = clampf(float(r.get("max_patience",65)),1,150)
            r["patience"] = clampf(float(r["patience"]), 0, float(r["max_patience"]))
            requests.append(r)
