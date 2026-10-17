extends Node
## All order and cart state lives here so switching screens never loses orders.
## Offline saves and progression; KitchenSync owns separate remote tickets.

signal cart_changed
signal orders_changed
signal game_changed

const SAVE_PATH: String = "user://cafe_shift_save.json"
const MENU = [
    {"id": "espresso", "name": "Double Espresso", "category": "Coffee", "description": "Bold, smooth, two perfect shots", "price": 120, "icon": "E"},
    {"id": "latte", "name": "Honey Latte", "category": "Coffee", "description": "Silky milk, espresso and honey", "price": 190, "icon": "L"},
    {"id": "coldbrew", "name": "Cold Brew", "category": "Coffee", "description": "18-hour steep, served over ice", "price": 170, "icon": "C"},
    {"id": "chai", "name": "Masala Chai", "category": "Tea", "description": "Cardamom, ginger, slow-brewed", "price": 90, "icon": "T"},
    {"id": "matcha", "name": "Iced Matcha", "category": "Tea", "description": "Earthy matcha with oat milk", "price": 220, "icon": "M"},
    {"id": "croissant", "name": "Butter Croissant", "category": "Bites", "description": "Golden layers, baked fresh", "price": 130, "icon": "B"},
    {"id": "toastie", "name": "Cheese Toastie", "category": "Bites", "description": "Sourdough and melted cheddar", "price": 210, "icon": "S"},
    {"id": "brownie", "name": "Fudge Brownie", "category": "Desserts", "description": "Dark chocolate, soft centre", "price": 160, "icon": "F"},
    {"id": "cookie", "name": "Choco-chip Cookie", "category": "Desserts", "description": "Crisp edge, gooey chocolate", "price": 110, "icon": "K"}
]

var cart: Dictionary = {}  # product_id -> integer quantity
var orders: Array[Dictionary] = []
var next_order_id: int = 101
var served_count: int = 0
var earnings: int = 0
var xp: int = 0
var best: Dictionary = {"score": 0, "served": 0, "streak": 0}
var save_path: String = SAVE_PATH
var persistence_enabled: bool = true
var last_error: String = ""
var shift: RefCounted = preload("res://scripts/shift_rules.gd").new()
var _save_clock: float = 0.0
var gameplay_running: bool = false
var tutorial_completed: bool = false
var _tutorial_backup: Dictionary = {}
const ACHIEVEMENTS: Dictionary = {
    "first_service":"First happy guest · finish an order",
    "silky_hands":"Silky hands · 3 perfect pours in a shift",
    "five_happy_tables":"Five happy tables · win Rush Hour",
    "perfect_shift":"Perfect shift · 5 excellent services",
    "vip_host":"VIP host · excellent VIP service"
}
var achievements: Array[String] = []
var last_unlocks: Array[String] = []

func _ready() -> void:
    load_data()
    # Loading is deliberately paused; the welcome screen owns the next action.
    gameplay_running = false
    if shift.requests.is_empty() and shift.active:
        shift.welcome()

func _process(delta: float) -> void:
    if not gameplay_running:
        return
    if shift.tick(delta):
        game_changed.emit()
        save_data()
    _save_clock += delta
    if _save_clock >= 5 and shift.mode == "RUSH" and shift.active:
        _save_clock = 0
        save_data()

func start_shift(mode: String, seed_value: int = -1) -> void:
    gameplay_running = true
    last_unlocks.clear()
    cart.clear()
    orders.clear()
    served_count = 0
    earnings = 0
    shift.start(mode,seed_value)
    save_data()
    cart_changed.emit()
    orders_changed.emit()
    game_changed.emit()

func welcome_customer() -> String:
    var request_id: String = shift.welcome()
    save_data()
    game_changed.emit()
    return request_id

func find_product(product_id: String) -> Dictionary:
    for product in MENU:
        if str(product["id"]) == product_id:
            return product
    return {}

func find_order(order_id: int) -> Dictionary:
    for order in orders:
        if int(order["id"]) == order_id:
            return order
    return {}

func save_preparation(order_id: int, state: Dictionary) -> void:
    var order: Dictionary = find_order(order_id)
    if order.is_empty() or str(order["status"]) == "DONE":
        return
    var progress: Dictionary = order.get("preparations", {})
    progress[str(state.get("product", ""))] = state.duplicate(true)
    order["preparations"] = progress
    if str(order["status"]) == "NEW":
        order["status"] = "PREPARING"
    save_data()
    orders_changed.emit()

func record_crafted_item(order_id: int, product_id: String, quality: int, pours: int = 0) -> bool:
    var order: Dictionary = find_order(order_id)
    if order.is_empty() or str(order["status"]) == "DONE":
        return false
    var required: int = 0
    for item in order["items"]:
        if str(item["id"]) == product_id:
            required = int(item["qty"])
    var crafted: Dictionary = order.get("crafted", {})
    if required == 0 or int(crafted.get(product_id, 0)) >= required:
        return false
    crafted[product_id] = int(crafted.get(product_id, 0)) + 1
    order["crafted"] = crafted
    order["craft_quality"] = int(order.get("craft_quality", 0)) + clampi(quality, 0, 20)
    var can_pour: bool = false
    for action in preload("res://scripts/recipes.gd").steps(product_id): can_pour = can_pour or str(action[0]) == "hold"
    order["perfect_pours"] = int(order.get("perfect_pours", 0)) + (clampi(pours,0,1) if can_pour else 0)
    if typeof(order.get("preparations")) == TYPE_DICTIONARY:
        order["preparations"].erase(product_id)
    order["status"] = "PREPARING"
    save_data()
    orders_changed.emit()
    return true

func tray_ready(order_id: int) -> bool:
    var order: Dictionary = find_order(order_id)
    if order.is_empty() or str(order["status"]) == "DONE":
        return false
    var crafted: Dictionary = order.get("crafted", {})
    for item in order["items"]:
        if int(crafted.get(str(item["id"]), 0)) != int(item["qty"]):
            return false
    return true

func deliver_crafted(order_id: int) -> bool:
    if not tray_ready(order_id) or (shift.mode == "RUSH" and not shift.active):
        return false
    var order: Dictionary = find_order(order_id)
    var count: int = 0
    for item in order["items"]:
        count += int(item["qty"])
    var quality: int = int(order.get("craft_quality", 0)) / maxi(1, count)
    return advance_order(order_id, quality)

func add_item(product_id: String) -> void:
    if find_product(product_id).is_empty():
        return
    cart[product_id] = mini(99, int(cart.get(product_id, 0)) + 1)
    save_data()
    cart_changed.emit()

func change_quantity(product_id: String, delta: int) -> void:
    if not cart.has(product_id):
        return
    var count: int = int(cart[product_id]) + delta
    if count <= 0:
        cart.erase(product_id)
    else:
        cart[product_id] = mini(99, count)
    save_data()
    cart_changed.emit()

func clear_cart() -> void:
    cart.clear()
    save_data()
    cart_changed.emit()

func cart_item_count() -> int:
    var count: int = 0
    for value in cart.values():
        count += int(value)
    return count

func cart_total() -> int:
    var total: int = 0
    for product_id in cart.keys():
        var product: Dictionary = find_product(str(product_id))
        if not product.is_empty():
            total += int(product["price"]) * int(cart[product_id])
    return total

func place_order(customer: String, table_number: String, request_id: String = "") -> int:
    last_error = ""
    if cart.is_empty():
        last_error = "Add something delicious to the cart first."
        return -1
    if shift.mode == "RUSH" and (not shift.active or request_id.is_empty()):
        last_error = "Select a waiting customer during Rush Hour."
        return -1
    if not request_id.is_empty():
        if not shift.matches(request_id, cart):
            last_error = "That cart does not match the request. Check items and quantities."
            return -1
        var request: Dictionary = shift.find_request(request_id)
        customer = str(request["name"])
        table_number = str(request["table"])
    var items: Array[Dictionary] = []
    for product_id in cart.keys():
        var product: Dictionary = find_product(str(product_id))
        if product.is_empty():
            continue
        var count: int = int(cart[product_id])
        if count > 0:
            items.append({"id": product_id, "name": product["name"], "qty": count, "price": product["price"]})
    if items.is_empty():
        return -1
    var order_id: int = _insert_order(items, customer, table_number)
    if not request_id.is_empty():
        shift.sent(request_id, order_id)
    cart.clear()
    save_data()
    cart_changed.emit()
    orders_changed.emit()
    game_changed.emit()
    return order_id

func add_walk_in() -> int:
    # Simulates an NPC/customer request. Does not touch the human operator's cart.
    var names: Array[String] = ["Mira", "Sam", "Noah", "Asha", "Leo", "Riya", "Kai"]
    var items: Array[Dictionary] = []
    var selected: Dictionary = {}
    for _i in range(randi_range(1, 3)):
        var product: Dictionary = MENU[randi_range(0, MENU.size() - 1)]
        var product_id: String = str(product["id"])
        if selected.has(product_id):
            selected[product_id]["qty"] = int(selected[product_id]["qty"]) + 1
        else:
            selected[product_id] = {"id": product_id, "name": product["name"], "qty": 1, "price": product["price"]}
    for key in selected.keys():
        items.append(selected[key])
    var order_id: int = _insert_order(items, names.pick_random(), str(randi_range(1, 9)))
    save_data()
    orders_changed.emit()
    return order_id

func _insert_order(items: Array[Dictionary], customer: String, table_number: String) -> int:
    var total: int = 0
    for line in items:
        total += int(line["price"]) * int(line["qty"])
    var order_id: int = next_order_id
    next_order_id += 1
    orders.push_front({
        "id": order_id,
        "customer": customer.strip_edges().substr(0, 28) if not customer.strip_edges().is_empty() else "Guest",
        "table": table_number.strip_edges().substr(0, 8) if not table_number.strip_edges().is_empty() else "Takeaway",
        "items": items,
        "total": total,
        "status": "NEW",
        "created_at": Time.get_datetime_string_from_system()
    })
    return order_id

func advance_order(order_id: int, quality_bonus: int = 0) -> bool:
    for i in range(orders.size()):
        if int(orders[i].get("id", -1)) != order_id:
            continue
        var old_status: String = str(orders[i].get("status", "NEW"))
        if old_status == "NEW":
            orders[i]["status"] = "PREPARING"
        elif old_status == "PREPARING":
            if bool(orders[i].get("hands_on",false)) and not tray_ready(order_id): return false
            orders[i]["status"] = "DONE"
            served_count += 1
            earnings += int(orders[i]["total"])
            var reward: int = 25 + shift.completed(order_id,clampi(quality_bonus,0,20),int(orders[i].get("perfect_pours",0))) + clampi(quality_bonus, 0, 20)
            xp += reward
            orders[i]["xp"] = reward
            orders[i]["quality_bonus"] = clampi(quality_bonus, 0, 20)
            orders[i]["service"] = shift.last_service.duplicate(true)
            if _tutorial_backup.is_empty():
                _unlock("first_service")
                if shift.perfect_pours >= 3: _unlock("silky_hands")
                if shift.result == "SUCCESS": _unlock("five_happy_tables")
                if shift.result == "SUCCESS" and shift.perfect_services >= 5: _unlock("perfect_shift")
                if str(shift.last_service.get("personality","")) == "VIP" and quality_bonus >= 16: _unlock("vip_host")
        else:
            return false
        save_data()
        orders_changed.emit()
        game_changed.emit()
        return true
    return false

func status_count(status: String) -> int:
    var count: int = 0
    for order in orders:
        if str(order.get("status", "")) == status:
            count += 1
    return count

func record_best() -> bool:
    ## Called once when a shift report is shown. Returns true if the score is a new record.
    if shift.mode != "RUSH" or not _tutorial_backup.is_empty():
        return false
    var new_score_best: bool = shift.result == "SUCCESS" and shift.score > int(best.get("score", 0))
    var changed: bool = false
    if new_score_best:
        best["score"] = shift.score
        changed = true
    if shift.served > int(best.get("served", 0)):
        best["served"] = shift.served
        changed = true
    if shift.best_streak > int(best.get("streak", 0)):
        best["streak"] = shift.best_streak
        changed = true
    if changed:
        save_data()
    return new_score_best

func reset_demo() -> void:
    achievements.clear()
    last_unlocks.clear()
    _tutorial_backup.clear()
    tutorial_completed = false
    cart.clear()
    orders.clear()
    next_order_id = 101
    served_count = 0
    earnings = 0
    xp = 0
    best = {"score": 0, "served": 0, "streak": 0}
    shift.start("FREE")
    save_data()
    cart_changed.emit()
    orders_changed.emit()
    game_changed.emit()

func _unlock(id: String) -> void:
    if id not in achievements:
        achievements.append(id)
        last_unlocks.append(id)

func _snapshot() -> Dictionary:
    return {"version":4,"cart":cart.duplicate(true),"orders":orders.duplicate(true),
        "next_order_id":next_order_id,"served_count":served_count,"earnings":earnings,
        "xp":xp,"best":best.duplicate(),"shift":shift.snapshot().duplicate(true),
        "tutorial_completed":tutorial_completed,"achievements":achievements.duplicate()}

func begin_tutorial() -> void:
    if not _tutorial_backup.is_empty(): return
    _tutorial_backup = _snapshot()
    start_shift("FREE",0)

func mark_tutorial_complete() -> void:
    if not _tutorial_backup.is_empty():
        tutorial_completed = true
        save_data()

func end_tutorial(completed: bool) -> void:
    if _tutorial_backup.is_empty(): return
    tutorial_completed = tutorial_completed or completed
    cart = _tutorial_backup["cart"]
    orders.assign(_tutorial_backup["orders"])
    next_order_id = int(_tutorial_backup["next_order_id"])
    served_count = int(_tutorial_backup["served_count"])
    earnings = int(_tutorial_backup["earnings"])
    xp = int(_tutorial_backup["xp"])
    best = _tutorial_backup["best"]
    achievements.assign(_tutorial_backup.get("achievements",[]))
    last_unlocks.clear()
    shift.restore(_tutorial_backup["shift"])
    _tutorial_backup.clear()
    gameplay_running = false
    save_data()
    cart_changed.emit()
    orders_changed.emit()
    game_changed.emit()

func save_data() -> void:
    if not persistence_enabled:
        return
    var file: FileAccess = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
    if file == null:
        push_warning("Save failed: " + str(FileAccess.get_open_error()))
        return
    # A lesson is a disposable local sandbox, even if the app closes mid-step.
    var data: Dictionary = _tutorial_backup.duplicate(true) if not _tutorial_backup.is_empty() else _snapshot()
    data["tutorial_completed"] = tutorial_completed
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    var error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path))
    if error != OK:
        last_error = "Could not save progress on this device."
        push_warning(last_error)

func load_data() -> void:
    if not persistence_enabled or not FileAccess.file_exists(save_path):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    if typeof(raw) != TYPE_DICTIONARY:
        push_warning("Ignoring invalid save file")
        return
    var state: Dictionary = raw
    if int(state.get("version", 1)) not in [1, 2, 3, 4]:
        last_error = "This save belongs to a newer version. It was left untouched."
        persistence_enabled = false
        return
    cart.clear()
    orders.clear()
    if typeof(state.get("cart", null)) == TYPE_DICTIONARY:
        for key in state["cart"].keys():
            var quantity: Variant = state["cart"][key]
            if not find_product(str(key)).is_empty() and typeof(quantity) in [TYPE_INT, TYPE_FLOAT] and int(quantity) > 0:
                cart[str(key)] = mini(99, int(quantity))
    if typeof(state.get("orders", null)) == TYPE_ARRAY:
        for candidate in state["orders"]:
            if typeof(candidate) != TYPE_DICTIONARY or typeof(candidate.get("id")) not in [TYPE_INT, TYPE_FLOAT] or typeof(candidate.get("items")) != TYPE_ARRAY:
                continue
            if int(candidate["id"]) < 101 or str(candidate.get("status", "")) not in ["NEW", "PREPARING", "DONE"]:
                continue
            var clean_items: Array[Dictionary] = []
            var total: int = 0
            for item in candidate["items"]:
                if typeof(item) != TYPE_DICTIONARY or typeof(item.get("qty")) not in [TYPE_INT, TYPE_FLOAT]:
                    continue
                var product: Dictionary = find_product(str(item.get("id", "")))
                if product.is_empty() or int(item["qty"]) < 1:
                    continue
                var qty: int = mini(99, int(item["qty"]))
                clean_items.append({"id": product["id"], "name": product["name"], "price": product["price"], "qty": qty})
                total += int(product["price"]) * qty
            var duplicate_id: bool = false
            for existing in orders:
                if int(existing["id"]) == int(candidate["id"]):
                    duplicate_id = true
            if clean_items.is_empty() or duplicate_id:
                continue
            candidate["items"] = clean_items
            candidate["total"] = total
            var clean_crafted: Dictionary = {}
            var raw_crafted: Variant = candidate.get("crafted", {})
            if typeof(raw_crafted) == TYPE_DICTIONARY:
                for item in clean_items:
                    var value: Variant = raw_crafted.get(str(item["id"]), 0)
                    if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
                        clean_crafted[str(item["id"])] = clampi(int(value), 0, int(item["qty"]))
            candidate["crafted"] = clean_crafted
            var raw_quality: Variant = candidate.get("craft_quality", 0)
            candidate["craft_quality"] = clampi(int(raw_quality), 0, 2000) if typeof(raw_quality) in [TYPE_INT, TYPE_FLOAT] else 0
            var raw_pours: Variant = candidate.get("perfect_pours",0)
            var crafted_count: int = 0
            for value in clean_crafted.values(): crafted_count += int(value)
            candidate["craft_quality"] = clampi(int(raw_quality),0,crafted_count*20) if typeof(raw_quality) in [TYPE_INT,TYPE_FLOAT] else 0
            candidate["perfect_pours"] = clampi(int(raw_pours),0,crafted_count) if typeof(raw_pours) in [TYPE_INT,TYPE_FLOAT] else 0
            var clean_preps: Dictionary = {}
            var preps: Variant = candidate.get("preparations", {})
            if typeof(preps) == TYPE_DICTIONARY:
                for key in preps:
                    var prep: Variant = preps[key]
                    if typeof(prep) == TYPE_DICTIONARY and typeof(prep.get("step")) in [TYPE_INT, TYPE_FLOAT] and typeof(prep.get("quality")) in [TYPE_INT, TYPE_FLOAT] and str(key) in clean_crafted:
                        clean_preps[str(key)] = {"product": str(key), "step": clampi(int(prep["step"]), 0, 3), "quality": clampi(int(prep["quality"]), 0, 20), "perfect_pours":clampi(int(prep.get("perfect_pours",0)),0,1)}
            candidate["preparations"] = clean_preps
            orders.append(candidate)
    next_order_id = maxi(101, int(state.get("next_order_id", 101)))
    served_count = maxi(0, int(state.get("served_count", 0)))
    earnings = maxi(0, int(state.get("earnings", 0)))
    xp = maxi(0, int(state.get("xp", served_count * 25)))
    tutorial_completed = state.get("tutorial_completed",false) == true
    achievements.clear()
    if typeof(state.get("achievements")) == TYPE_ARRAY:
        for id in state["achievements"]:
            if str(id) in ACHIEVEMENTS and str(id) not in achievements: achievements.append(str(id))
    best = {"score": 0, "served": 0, "streak": 0}
    if typeof(state.get("best")) == TYPE_DICTIONARY:
        var best_state: Dictionary = state["best"]
        for key in best.keys():
            var value: Variant = best_state.get(key)
            if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
                best[key] = maxi(0, int(value))
    for order in orders:
        next_order_id = maxi(next_order_id, int(order["id"]) + 1)
    if typeof(state.get("shift")) == TYPE_DICTIONARY:
        shift.restore(state["shift"])
