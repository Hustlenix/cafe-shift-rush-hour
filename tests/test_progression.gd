extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, text: String) -> void:
    checks += 1
    if not value: failures.append(text)
func ticket(store: Node) -> int:
    if store.shift.requests.is_empty(): store.welcome_customer()
    var request: Dictionary = store.shift.requests[0]
    store.cart = request["recipe"].duplicate()
    return store.place_order("","",str(request["id"]))
func _run() -> void:
    var store: Node = load("res://scripts/order_store.gd").new()
    store.persistence_enabled = false
    store.start_shift("RUSH",0)
    for _i in range(5):
        var id: int = ticket(store)
        var order: Dictionary = store.find_order(id)
        order["hands_on"] = true
        check(store.advance_order(id),"Preparation transition accepted")
        check(not store.advance_order(id),"Unprepared item prevents completion")
        for line in order["items"]:
            for _j in range(int(line["qty"])): store.record_crafted_item(id,str(line["id"]),20,1)
        check(store.deliver_crafted(id),"Complete high-quality tray accepted")
        var xp: int = store.xp
        check(not store.deliver_crafted(id) and store.xp == xp,"Duplicate delivery gives no reward")
    check(store.shift.perfect_services == 5 and store.shift.quality_total == 100,"Quality is aggregated from real completed orders")
    for id in ["first_service","silky_hands","five_happy_tables","perfect_shift"]:
        check(id in store.achievements,"Genuine achievement: "+id)
    check(store.shift.perfect_pours == 5,"Foods and steeped tea cannot masquerade as pours")
    check(store.last_unlocks.size() == 4,"Achievements unlock once")
    check(store.record_best(),"Winning run updates records")
    var xp: int = store.xp
    var trophies: Array = store.achievements.duplicate()
    store.begin_tutorial()
    var lesson: int = ticket(store)
    store.advance_order(lesson)
    store.advance_order(lesson,20)
    store.end_tutorial(true)
    check(store.xp == xp and store.achievements == trophies,"Lesson sandbox preserves real progression")
    store.save_path = "user://progression_fixture_%d.json" % Time.get_ticks_usec()
    store.persistence_enabled = true
    store.save_data()
    var restored: Node = load("res://scripts/order_store.gd").new()
    restored.save_path = store.save_path
    restored._ready()
    check(restored.xp == xp and restored.achievements == trophies,"Progression survives a fresh store")
    check(restored.shift.perfect_pours == 5 and restored.shift.quality_total == 100,"Service statistics persist")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.save_path))
    raw["version"] = 3
    raw.erase("achievements")
    var file := FileAccess.open(store.save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(raw))
    file.close()
    restored.load_data()
    check(restored.achievements.is_empty() and restored.xp == xp,"Version 3 migrates without inventing achievements")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
    store.free()
    restored.free()
    print("PASS" if failures.is_empty() else "FAIL",": ",checks," progression checks / ",failures.size()," failures")
    for text in failures: push_error(text)
    quit(0 if failures.is_empty() else 1)
