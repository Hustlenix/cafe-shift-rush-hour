extends Node
## All order and cart state lives here so switching screens never loses orders.
## This is a local, single-device demo; cross-device realtime needs a server.

signal cart_changed
signal orders_changed

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

func _ready() -> void:
    load_data()

func find_product(product_id: String) -> Dictionary:
    for product in MENU:
        if str(product["id"]) == product_id:
            return product
    return {}

func add_item(product_id: String) -> void:
    if find_product(product_id).is_empty():
        return
    cart[product_id] = int(cart.get(product_id, 0)) + 1
    save_data()
    cart_changed.emit()

func change_quantity(product_id: String, delta: int) -> void:
    if not cart.has(product_id):
        return
    var count: int = int(cart[product_id]) + delta
    if count <= 0:
        cart.erase(product_id)
    else:
        cart[product_id] = count
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

func place_order(customer: String, table_number: String) -> int:
    if cart.is_empty():
        return -1
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
    cart.clear()
    save_data()
    cart_changed.emit()
    orders_changed.emit()
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

func advance_order(order_id: int) -> bool:
    for i in range(orders.size()):
        if int(orders[i].get("id", -1)) != order_id:
            continue
        var old_status: String = str(orders[i].get("status", "NEW"))
        if old_status == "NEW":
            orders[i]["status"] = "PREPARING"
        elif old_status == "PREPARING":
            orders[i]["status"] = "DONE"
            served_count += 1
            earnings += int(orders[i]["total"])
        else:
            return false
        save_data()
        orders_changed.emit()
        return true
    return false

func status_count(status: String) -> int:
    var count: int = 0
    for order in orders:
        if str(order.get("status", "")) == status:
            count += 1
    return count

func reset_demo() -> void:
    cart.clear()
    orders.clear()
    next_order_id = 101
    served_count = 0
    earnings = 0
    save_data()
    cart_changed.emit()
    orders_changed.emit()

func save_data() -> void:
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Save failed: " + str(FileAccess.get_open_error()))
        return
    file.store_string(JSON.stringify({
        "version": 1,
        "cart": cart,
        "orders": orders,
        "next_order_id": next_order_id,
        "served_count": served_count,
        "earnings": earnings
    }, "  "))
    file.close()

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if typeof(raw) != TYPE_DICTIONARY:
        push_warning("Ignoring invalid save file")
        return
    var state: Dictionary = raw
    if typeof(state.get("cart", null)) == TYPE_DICTIONARY:
        for key in state["cart"].keys():
            if not find_product(str(key)).is_empty():
                cart[str(key)] = maxi(0, int(state["cart"][key]))
    if typeof(state.get("orders", null)) == TYPE_ARRAY:
        for candidate in state["orders"]:
            if typeof(candidate) == TYPE_DICTIONARY and candidate.has("id") and candidate.has("items"):
                orders.append(candidate)
    next_order_id = maxi(101, int(state.get("next_order_id", 101)))
    served_count = maxi(0, int(state.get("served_count", 0)))
    earnings = maxi(0, int(state.get("earnings", 0)))
