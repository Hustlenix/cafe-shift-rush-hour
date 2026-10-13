extends Control
## UI is created from native Godot Controls, not HTML or an embedded webpage.
## Switch between POS and kitchen. Both read the same OrderStore autoload.

const BG: Color = Color("#0e1420")
const PANEL: Color = Color("#182435")
const PANEL_ALT: Color = Color("#202f42")
const TILE: Color = Color("#28384c")
const BORDER: Color = Color("#354961")
const TEXT: Color = Color("#f8f7f2")
const MUTED: Color = Color("#aab7ca")
const AMBER: Color = Color("#ffbc74")
const GREEN: Color = Color("#71e0b5")
const BLUE: Color = Color("#7dcaf6")
const RED: Color = Color("#f8a3a3")

var active_screen: String = "ORDER"
var active_category: String = "All"
var search_query: String = ""
var customer_name: String = ""
var table_number: String = ""
var message: String = "Your counter is ready. Add an item to begin."
var _menu_grid: GridContainer
var _refresh_queued: bool = false
var _reset_confirmation: ConfirmationDialog

func _ready() -> void:
    OrderStore.cart_changed.connect(_request_refresh)
    OrderStore.orders_changed.connect(_request_refresh)
    _build_ui()

func _request_refresh() -> void:
    if _refresh_queued:
        return
    _refresh_queued = true
    call_deferred("_build_ui")

func _style(background: Color, outline: Color = BORDER, radius: int = 12) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = outline
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 13.0
    style.content_margin_right = 13.0
    style.content_margin_top = 11.0
    style.content_margin_bottom = 11.0
    return style

func _panel(background: Color = PANEL, outline: Color = BORDER, radius: int = 14) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(background, outline, radius))
    return panel

func _label(value: String, font_size: int = 16, tint: Color = TEXT) -> Label:
    var label: Label = Label.new()
    label.text = value
    label.add_theme_color_override("font_color", tint)
    label.add_theme_font_size_override("font_size", font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _column(separation: int = 10) -> VBoxContainer:
    var v: VBoxContainer = VBoxContainer.new()
    v.add_theme_constant_override("separation", separation)
    return v

func _row(separation: int = 10) -> HBoxContainer:
    var h: HBoxContainer = HBoxContainer.new()
    h.add_theme_constant_override("separation", separation)
    return h

func _button(value: String, callback: Callable, emphasis: bool = false, min_height: int = 42) -> Button:
    var btn: Button = Button.new()
    btn.text = value
    btn.custom_minimum_size = Vector2(0, min_height)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var normal: Color = AMBER if emphasis else TILE
    var hovered: Color = Color("#ffd29b") if emphasis else Color("#3a506b")
    var foreground: Color = Color("#17202d") if emphasis else TEXT
    btn.add_theme_stylebox_override("normal", _style(normal, normal, 9))
    btn.add_theme_stylebox_override("hover", _style(hovered, hovered, 9))
    btn.add_theme_stylebox_override("pressed", _style(PANEL_ALT, AMBER, 9))
    btn.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), BLUE, 9))
    btn.add_theme_color_override("font_color", foreground)
    btn.add_theme_color_override("font_hover_color", Color("#17202d") if emphasis else TEXT)
    btn.add_theme_color_override("font_pressed_color", TEXT)
    btn.add_theme_font_size_override("font_size", 14)
    btn.pressed.connect(callback)
    return btn

func _spacer() -> Control:
    var spacer: Control = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return spacer

func _stat_pill(value: String, tint: Color = MUTED) -> PanelContainer:
    var p: PanelContainer = _panel(PANEL_ALT)
    p.add_child(_label(value, 13, tint))
    return p

func _switch_screen(screen: String) -> void:
    active_screen = screen
    _request_refresh()

func _notify(value: String) -> void:
    message = value
    _request_refresh()

func _build_ui() -> void:
    _refresh_queued = false
    for child in get_children():
        child.queue_free()
    _menu_grid = null
    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = BG
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)

    var margins: MarginContainer = MarginContainer.new()
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margins.add_theme_constant_override("margin_left", 22)
    margins.add_theme_constant_override("margin_right", 22)
    margins.add_theme_constant_override("margin_top", 18)
    margins.add_theme_constant_override("margin_bottom", 18)
    add_child(margins)

    var page: VBoxContainer = _column(15)
    margins.add_child(page)
    page.add_child(_build_header())
    var content: Control
    if active_screen == "KITCHEN":
        content = _build_kitchen()
    else:
        content = _build_order_desk()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(content)
    page.add_child(_build_footer())

    _reset_confirmation = ConfirmationDialog.new()
    _reset_confirmation.title = "Reset demo data?"
    _reset_confirmation.dialog_text = "Clear all tickets, revenue, points, and the cart? This cannot be undone."
    _reset_confirmation.confirmed.connect(_on_reset_confirmed)
    add_child(_reset_confirmation)

func _build_header() -> PanelContainer:
    var outer: PanelContainer = _panel(PANEL)
    var h: HBoxContainer = _row(14)
    outer.add_child(h)

    var title: VBoxContainer = _column(2)
    title.custom_minimum_size.x = 226
    title.add_child(_label("CAFE / SHIFT", 27, AMBER))
    title.add_child(_label("A tiny cafe. A busy day.", 12, MUTED))
    h.add_child(title)

    var tab_order: Button = _button("ORDER DESK", func(): _switch_screen("ORDER"), active_screen == "ORDER")
    tab_order.custom_minimum_size.x = 130
    h.add_child(tab_order)
    var tab_kitchen: Button = _button("KITCHEN BOARD", func(): _switch_screen("KITCHEN"), active_screen == "KITCHEN")
    tab_kitchen.custom_minimum_size.x = 152
    h.add_child(tab_kitchen)
    h.add_child(_spacer())
    h.add_child(_stat_pill("SERVED  %02d / 05" % mini(OrderStore.served_count, 5), GREEN))
    h.add_child(_stat_pill("XP  %d" % (OrderStore.served_count * 25), AMBER))
    h.add_child(_stat_pill("Rs %d" % OrderStore.earnings, TEXT))
    return outer

func _build_order_desk() -> HBoxContainer:
    var horizontal: HBoxContainer = _row(16)
    var menu_section: VBoxContainer = _column(13)
    menu_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    horizontal.add_child(menu_section)

    var menu_heading: VBoxContainer = _column(2)
    menu_heading.add_child(_label("01  /  The menu", 24, TEXT))
    menu_heading.add_child(_label("Everything your customers love, ready to order.", 13, MUTED))
    menu_section.add_child(menu_heading)

    var search: LineEdit = LineEdit.new()
    search.placeholder_text = "Search drinks, snacks and desserts..."
    search.text = search_query
    search.custom_minimum_size.y = 46
    search.add_theme_stylebox_override("normal", _style(PANEL, BORDER, 10))
    search.add_theme_color_override("font_color", TEXT)
    search.add_theme_color_override("font_placeholder_color", MUTED)
    search.text_changed.connect(func(value: String):
        search_query = value
        _refresh_menu_grid()
    )
    menu_section.add_child(search)

    var categories: HBoxContainer = _row(6)
    for category in ["All", "Coffee", "Tea", "Bites", "Desserts"]:
        var category_value: String = category
        categories.add_child(_button(category_value, func(): _select_category(category_value), active_category == category_value, 37))
    menu_section.add_child(categories)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    menu_section.add_child(scroll)
    _menu_grid = GridContainer.new()
    _menu_grid.columns = 2
    _menu_grid.add_theme_constant_override("h_separation", 12)
    _menu_grid.add_theme_constant_override("v_separation", 12)
    _menu_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_menu_grid)
    _refresh_menu_grid()

    var receipt: PanelContainer = _panel(PANEL)
    receipt.custom_minimum_size.x = 373
    receipt.size_flags_vertical = Control.SIZE_EXPAND_FILL
    horizontal.add_child(receipt)
    var right: VBoxContainer = _column(11)
    receipt.add_child(right)
    right.add_child(_label("02  /  Current cart", 22, TEXT))
    right.add_child(_label("%d items selected" % OrderStore.cart_item_count(), 13, MUTED))

    right.add_child(_label("CUSTOMER NAME", 11, AMBER))
    var name_input: LineEdit = _input("Guest name (optional)", customer_name)
    name_input.text_changed.connect(func(value: String): customer_name = value)
    right.add_child(name_input)

    right.add_child(_label("TABLE / PICKUP", 11, AMBER))
    var table_input: LineEdit = _input("Table number or takeaway", table_number)
    table_input.text_changed.connect(func(value: String): table_number = value)
    right.add_child(table_input)

    var cart_scroll: ScrollContainer = ScrollContainer.new()
    cart_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cart_scroll.custom_minimum_size.y = 160
    cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right.add_child(cart_scroll)
    var cart_items: VBoxContainer = _column(8)
    cart_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cart_scroll.add_child(cart_items)
    if OrderStore.cart.is_empty():
        cart_items.add_child(_label("Your tray is empty.\n\nPick something tasty from the menu.", 15, MUTED))
    else:
        for product_id in OrderStore.cart.keys():
            var product: Dictionary = OrderStore.find_product(str(product_id))
            if product.is_empty():
                continue
            cart_items.add_child(_cart_line(product, int(OrderStore.cart[product_id])))

    var horizontal_rule: HSeparator = HSeparator.new()
    right.add_child(horizontal_rule)
    var total: HBoxContainer = _row()
    total.add_child(_label("TOTAL", 16, MUTED))
    total.add_child(_spacer())
    total.add_child(_label("Rs %d" % OrderStore.cart_total(), 26, AMBER))
    right.add_child(total)

    var place: Button = _button("SEND ORDER TO KITCHEN  >", _place_order, true, 52)
    place.disabled = OrderStore.cart.is_empty()
    right.add_child(place)
    var actions: HBoxContainer = _row()
    var clear: Button = _button("Clear cart", func(): OrderStore.clear_cart(), false, 38)
    clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(clear)
    var go_kitchen: Button = _button("Kitchen ->", func(): _switch_screen("KITCHEN"), false, 38)
    go_kitchen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(go_kitchen)
    right.add_child(actions)
    return horizontal

func _input(placeholder: String, current_value: String) -> LineEdit:
    var field: LineEdit = LineEdit.new()
    field.placeholder_text = placeholder
    field.text = current_value
    field.custom_minimum_size.y = 43
    field.add_theme_stylebox_override("normal", _style(PANEL_ALT))
    field.add_theme_color_override("font_color", TEXT)
    field.add_theme_color_override("font_placeholder_color", MUTED)
    return field

func _select_category(category: String) -> void:
    active_category = category
    _request_refresh()

func _refresh_menu_grid() -> void:
    if not is_instance_valid(_menu_grid):
        return
    for child in _menu_grid.get_children():
        child.queue_free()
    var matches: int = 0
    for product in OrderStore.MENU:
        if active_category != "All" and str(product["category"]) != active_category:
            continue
        var needle: String = search_query.to_lower().strip_edges()
        var haystack: String = (str(product["name"]) + " " + str(product["description"])).to_lower()
        if not needle.is_empty() and not haystack.contains(needle):
            continue
        _menu_grid.add_child(_menu_card(product))
        matches += 1
    if matches == 0:
        _menu_grid.add_child(_label("No matching items. Try another category.", 16, MUTED))

func _menu_card(product: Dictionary) -> PanelContainer:
    var card: PanelContainer = _panel(PANEL, BORDER)
    card.custom_minimum_size = Vector2(245, 168)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var inner: VBoxContainer = _column(7)
    card.add_child(inner)
    var first: HBoxContainer = _row(8)
    var icon_chip: PanelContainer = _panel(TILE, TILE, 8)
    icon_chip.add_child(_label(str(product["icon"]), 19, AMBER))
    first.add_child(icon_chip)
    var n: VBoxContainer = _column(2)
    n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    n.add_child(_label(str(product["name"]), 16, TEXT))
    n.add_child(_label(str(product["category"]).to_upper(), 10, AMBER))
    first.add_child(n)
    inner.add_child(first)
    inner.add_child(_label(str(product["description"]), 12, MUTED))
    var fill: Control = Control.new()
    fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
    inner.add_child(fill)
    var bottom: HBoxContainer = _row(10)
    bottom.add_child(_label("Rs %d" % int(product["price"]), 18, TEXT))
    bottom.add_child(_spacer())
    var product_id: String = str(product["id"])
    var add: Button = _button("+ ADD", func(): OrderStore.add_item(product_id), true, 35)
    bottom.add_child(add)
    inner.add_child(bottom)
    return card

func _cart_line(product: Dictionary, count: int) -> PanelContainer:
    var line: PanelContainer = _panel(PANEL_ALT, BORDER, 10)
    var content: VBoxContainer = _column(5)
    line.add_child(content)
    var top: HBoxContainer = _row(6)
    var name: Label = _label(str(product["name"]), 14, TEXT)
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(name)
    top.add_child(_label("Rs %d" % (int(product["price"]) * count), 14, AMBER))
    content.add_child(top)
    var controls: HBoxContainer = _row(6)
    controls.add_child(_label("Rs %d each" % int(product["price"]), 11, MUTED))
    controls.add_child(_spacer())
    var product_id: String = str(product["id"])
    controls.add_child(_button("-", func(): OrderStore.change_quantity(product_id, -1), false, 30))
    controls.add_child(_label(str(count), 13, TEXT))
    controls.add_child(_button("+", func(): OrderStore.change_quantity(product_id, 1), false, 30))
    content.add_child(controls)
    return line

func _place_order() -> void:
    var id: int = OrderStore.place_order(customer_name, table_number)
    if id < 0:
        message = "Add at least one item before sending an order."
    else:
        message = "Order #%d sent! Open the kitchen to prepare it." % id
        customer_name = ""
        table_number = ""
    _request_refresh()

func _build_kitchen() -> VBoxContainer:
    var content: VBoxContainer = _column(15)
    var toolbar: HBoxContainer = _row(14)
    var intro: VBoxContainer = _column(3)
    intro.add_child(_label("03  /  Kitchen display", 24, TEXT))
    intro.add_child(_label("Tickets update as soon as orders are submitted or advanced.", 13, MUTED))
    toolbar.add_child(intro)
    toolbar.add_child(_spacer())
    toolbar.add_child(_button("+ GENERATE WALK-IN", _add_walk_in, true, 44))
    toolbar.add_child(_button("BACK TO MENU", func(): _switch_screen("ORDER"), false, 44))
    content.add_child(toolbar)

    var board: HBoxContainer = _row(15)
    board.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(board)
    board.add_child(_ticket_column("NEW", "01  INCOMING", AMBER))
    board.add_child(_ticket_column("PREPARING", "02  IN PROGRESS", BLUE))
    board.add_child(_ticket_column("DONE", "03  COMPLETED", GREEN))
    return content

func _ticket_column(status: String, title_text: String, color: Color) -> PanelContainer:
    var col_panel: PanelContainer = _panel(PANEL)
    col_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var col: VBoxContainer = _column(12)
    col_panel.add_child(col)
    var heading: HBoxContainer = _row()
    var heading_label: Label = _label(title_text, 18, color)
    heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(heading_label)
    heading.add_child(_stat_pill(str(OrderStore.status_count(status)), color))
    col.add_child(heading)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(scroll)
    var tickets: VBoxContainer = _column(11)
    tickets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(tickets)
    var found: int = 0
    for order in OrderStore.orders:
        if str(order.get("status", "")) != status:
            continue
        found += 1
        tickets.add_child(_ticket_card(order, color))
    if found == 0:
        tickets.add_child(_label("No tickets here yet.\n\nNew orders will show up automatically.", 14, MUTED))
    return col_panel

func _ticket_card(order: Dictionary, color: Color) -> PanelContainer:
    var panel: PanelContainer = _panel(PANEL_ALT, color, 10)
    var body: VBoxContainer = _column(10)
    panel.add_child(body)
    var top: HBoxContainer = _row(6)
    var id_label: Label = _label("#%d" % int(order.get("id", 0)), 20, color)
    id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(id_label)
    top.add_child(_label(str(order.get("table", "Takeaway")), 12, MUTED))
    body.add_child(top)
    body.add_child(_label(str(order.get("customer", "Guest")), 15, TEXT))
    body.add_child(_label(str(order.get("created_at", "")).replace("T", "  "), 11, MUTED))
    for line in order.get("items", []):
        if typeof(line) == TYPE_DICTIONARY:
            body.add_child(_label("%d x %s" % [int(line.get("qty", 0)), str(line.get("name", "Item"))], 14, TEXT))
    var rule: HSeparator = HSeparator.new()
    body.add_child(rule)
    body.add_child(_label("TOTAL     Rs %d" % int(order.get("total", 0)), 14, AMBER))
    if str(order.get("status", "")) == "DONE":
        body.add_child(_label("[ COMPLETE ]   +25 XP", 13, GREEN))
    else:
        var id: int = int(order.get("id", 0))
        var text_value: String = "START PREPARING  >" if str(order.get("status", "")) == "NEW" else "MARK ORDER DONE  >"
        body.add_child(_button(text_value, func(): _advance(id), true, 40))
    return panel

func _advance(order_id: int) -> void:
    if OrderStore.advance_order(order_id):
        message = "Ticket #%d updated." % order_id
    _request_refresh()

func _add_walk_in() -> void:
    var id: int = OrderStore.add_walk_in()
    message = "A new walk-in customer placed order #%d." % id
    _request_refresh()

func _build_footer() -> PanelContainer:
    var footer: PanelContainer = _panel(PANEL)
    var h: HBoxContainer = _row(10)
    footer.add_child(h)
    var active_indicator: Label = _label("* LIVE LOCAL", 12, GREEN)
    h.add_child(active_indicator)
    var status: Label = _label(message, 12, MUTED)
    status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(status)
    h.add_child(_label("Saved on this device", 11, MUTED))
    var reset: Button = _button("RESET DEMO", _ask_reset, false, 31)
    h.add_child(reset)
    return footer

func _ask_reset() -> void:
    _reset_confirmation.popup_centered()

func _on_reset_confirmed() -> void:
    OrderStore.reset_demo()
    customer_name = ""
    table_number = ""
    message = "Demo reset. Start a fresh shift."
    _request_refresh()
