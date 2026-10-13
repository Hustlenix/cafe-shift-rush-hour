## Optional CLI logic test (needs Godot installed):
## godot --headless --path . --script res://tests/test_orders.gd
## Makes a temporary local save and restores the original save afterwards.
extends SceneTree

const SAVE: String = "user://cafe_shift_save.json"

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var had_save: bool = FileAccess.file_exists(SAVE)
    var original_bytes: PackedByteArray = PackedByteArray()
    if had_save:
        original_bytes = FileAccess.get_file_as_bytes(SAVE)

    var store: Node = load("res://scripts/order_store.gd").new()
    var errors: Array[String] = []

    if store.cart_total() != 0:
        errors.append("Cart must initially be empty")
    if store.place_order("", "") != -1:
        errors.append("Empty orders must be rejected")
    store.add_item("latte")
    store.add_item("latte")
    store.add_item("chai")
    if store.cart_total() != 470:
        errors.append("2 lattes + 1 chai must cost Rs 470")
    store.change_quantity("latte", -1)
    if store.cart_total() != 280:
        errors.append("Removing one latte must update total to Rs 280")
    var first: int = store.place_order("Test Customer", "7")
    if first != 101 or store.orders.size() != 1 or not store.cart.is_empty():
        errors.append("Order creation, ID or clearing cart is incorrect")
    if store.status_count("NEW") != 1:
        errors.append("New order must appear in the NEW kitchen column")
    if not store.advance_order(first) or store.status_count("PREPARING") != 1:
        errors.append("NEW -> PREPARING transition failed")
    if not store.advance_order(first) or store.status_count("DONE") != 1:
        errors.append("PREPARING -> DONE transition failed")
    if store.advance_order(first):
        errors.append("DONE orders must not advance twice")
    if store.served_count != 1 or store.earnings != 280:
        errors.append("Points/revenue must count only once")
    var before_cart: int = store.cart_item_count()
    var npc_id: int = store.add_walk_in()
    if npc_id != 102 or store.cart_item_count() != before_cart:
        errors.append("Walk-in should be a new ticket without changing current cart")
    if store.orders.size() != 2:
        errors.append("Two orders should coexist")

    # Restore data even if tests have failed, so running tests is non-destructive.
    if had_save:
        var backup: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
        if backup != null:
            backup.store_buffer(original_bytes)
            backup.close()
    elif FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

    store.free()
    if errors.is_empty():
        print("PASS: cart, totals, placement, kitchen statuses, scoring and NPC ticket")
        quit(0)
    else:
        for error in errors:
            push_error("FAIL: " + error)
        quit(1)
