extends SceneTree
var failures: Array[String] = []
var checks: int = 0
const Prep = preload("res://scripts/preparation.gd")
const Recipes = preload("res://scripts/recipes.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, text: String) -> void:
    checks += 1
    if not value: failures.append(text)

func _run() -> void:
    for product in Recipes.DATA:
        var prep: RefCounted = Prep.new()
        prep.begin(product)
        var events: Array[int] = [0]
        prep.completed.connect(func(): events[0] += 1)
        var expected: int = Recipes.steps(product).size()
        for i in range(expected):
            check(prep.index == i and events[0] == 0, product + ": cannot skip step " + str(i))
            match prep.kind():
                "pick": prep.press()
                "stack":
                    prep.press()
                    check(prep.index == i and prep.count == 1, product + ": one ingredient is insufficient")
                    prep.press()
                    prep.press()
                "hold":
                    prep.press()
                    prep.tick(0.1)
                    prep.release()
                    check(prep.index == i and prep.progress == 0, product + ": early release retries")
                    prep.press()
                    for _j in range(18): prep.tick(0.1)
                    prep.release()
                "heat":
                    prep.press()
                    prep.press()
                    check(prep.index == i and not prep.running, product + ": early heat lift retries")
                    prep.press()
                    for _j in range(45): prep.tick(0.1)
                    check(prep.index == i and not prep.running, product + ": burnt batch can recover")
                    prep.press()
                    for _j in range(30): prep.tick(0.1)
                    prep.press()
                "stir":
                    for _j in range(15): prep.stir(1)
                    check(prep.count == 1 and prep.index == i, product + ": one direction cannot fake whisking")
                    for j in range(7): prep.stir(-1 if j % 2 == 0 else 1)
                "cut":
                    prep.cut(Vector2(0, 0), Vector2(1, 1))
                    check(prep.index == i, product + ": wrong cut does not finish")
                    prep.cut(Vector2(0.5, 0.1), Vector2(0.5, 0.9))
                "plate":
                    prep.plate(false)
                    check(prep.index == i, product + ": dropping off-plate retains food")
                    prep.plate(true)
            check(prep.index == i + 1, product + ": correct action advances exactly once")
        check(events[0] == 1 and prep.quality <= 20, product + ": one completion and bounded quality")
        prep.press()
        prep.plate(true)
        check(events[0] == 1, product + ": completed item cannot duplicate itself")
    var store: Node = load("res://scripts/order_store.gd").new()
    store.persistence_enabled = false
    store.start_shift("FREE")
    store.add_item("cookie")
    var id: int = store.take_counter_request("R1")
    check(id == 101 and store.cart == {"cookie": 1}, "Taking a physical request preserves the operations cart")
    check(store.take_counter_request("R1") == id and store.orders.size() == 1, "Taking the same request resumes its ticket")
    check(not store.deliver_crafted(id), "Cannot deliver unprepared order")
    store.save_preparation(id, {"product":"latte", "step":2, "quality":7})
    check(not store.record_crafted_item(id, "cookie", 20), "Cannot craft an unrequested item onto the tray")
    check(store.record_crafted_item(id, "croissant", 11), "Prepared requested item is plated")
    check(not store.record_crafted_item(id, "croissant", 11), "Cannot overfill tray")
    check(not store.tray_ready(id), "One missing drink blocks delivery")
    store.save_path = "user://counter_test_%d.json" % Time.get_ticks_usec()
    store.persistence_enabled = true
    store.save_data()
    var restored: Node = load("res://scripts/order_store.gd").new()
    restored.save_path = store.save_path
    restored.load_data()
    check(restored.find_order(id)["crafted"] == {"latte":0,"croissant":1}, "Tray counts survive save/load")
    var checkpoint: Dictionary = restored.find_order(id)["preparations"]["latte"]
    check(checkpoint["step"] == 2, "Recipe checkpoint survives save/load")
    var resumed: RefCounted = Prep.new()
    resumed.begin("latte", checkpoint)
    check(resumed.kind() == "stir" and not resumed.holding and resumed.progress == 0, "Only unfinished gesture restarts on load")
    check(restored.record_crafted_item(id, "latte", 20) and restored.tray_ready(id), "Exact finished tray can be carried")
    check(restored.deliver_crafted(id) and restored.status_count("DONE") == 1, "Physical handoff completes kitchen state")
    var xp: int = restored.xp
    check(not restored.deliver_crafted(id) and restored.xp == xp, "Repeated handoff cannot duplicate XP")
    store.persistence_enabled = false
    store.start_shift("RUSH")
    for _i in range(5):
        if store.shift.requests.is_empty(): store.welcome_customer()
        var request: Dictionary = store.shift.requests[0]
        var ticket: int = store.take_counter_request(str(request["id"]))
        for item in store.find_order(ticket)["items"]:
            for _j in range(int(item["qty"])): store.record_crafted_item(ticket, str(item["id"]), 15)
        check(store.deliver_crafted(ticket), "Complete crafted rush tray can be handed over")
    check(store.shift.result == "SUCCESS" and store.shift.served == 5 and not store.shift.active, "Five physical deliveries finish the rush")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
    store.free()
    restored.free()
    print("PASS" if failures.is_empty() else "FAIL", ": ", checks, " preparation checks / ", failures.size(), " failures")
    for failure in failures: push_error(failure)
    quit(0 if failures.is_empty() else 1)
