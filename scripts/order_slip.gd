extends VBoxContainer
## A single active request, with stable physical-item selectors.
signal product_selected(product: String)
const CounterTheme = preload("res://scripts/counter_theme.gd")
const Recipes = preload("res://scripts/recipes.gd")
const SHORT: Dictionary = {"espresso":"Espresso", "latte":"Honey latte", "coldbrew":"Cold brew", "chai":"Chai", "matcha":"Matcha", "croissant":"Croissant", "toastie":"Toastie", "brownie":"Brownie", "cookie":"Cookie"}
var guest: Label
var row: HBoxContainer
var buttons: Dictionary = {}
var order_id: int = -1

func _ready() -> void:
    add_theme_constant_override("separation", 6)
    guest = CounterTheme.label("Tap a guest in the café", 20)
    add_child(guest)
    row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    add_child(row)

func show_order(order: Dictionary, selected: String) -> void:
    if order.is_empty():
        guest.text = "Tap a guest in the café"
        for child in row.get_children(): child.queue_free()
        buttons.clear()
        order_id = -1
        return
    if order_id != int(order["id"]):
        for child in row.get_children():
            row.remove_child(child)
            child.queue_free()
        buttons.clear()
        order_id = int(order["id"])
        for item in order["items"]:
            var id: String = str(item["id"])
            var button := CounterTheme.button("", func(): product_selected.emit(id), "Craft_" + id)
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            button.icon = Recipes.texture(id)
            button.expand_icon = true
            button.add_theme_constant_override("icon_max_width", 32)
            button.add_theme_font_size_override("font_size", 14)
            button.add_theme_color_override("font_disabled_color", CounterTheme.INK)
            button.add_theme_stylebox_override("disabled", CounterTheme.panel(Color("bdcba7")))
            buttons[id] = button
            row.add_child(button)
    guest.text = str(order["customer"]) + " would like..."
    var crafted: Dictionary = order.get("crafted", {})
    for item in order["items"]:
        var id: String = str(item["id"])
        var done: int = int(crafted.get(id, 0))
        var button: Button = buttons[id]
        button.text = "%s  %d/%d" % [SHORT[id], done, int(item["qty"])]
        button.disabled = done >= int(item["qty"])
        button.add_theme_stylebox_override("normal", CounterTheme.panel(CounterTheme.GOLD if id == selected else CounterTheme.PAPER))
