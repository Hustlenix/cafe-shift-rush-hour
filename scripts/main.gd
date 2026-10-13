extends Control
## Native Godot UI; stable form fields survive cart and kitchen updates.

const BG := Color("f6e9d0")
const PAPER := Color("fff5df")
const INK := Color("493a39")
const MUTED := Color("806c62")
const LINE := Color("dbc5a6")
const CORAL := Color("a84f41")
const GREEN := Color("396e61")
const GOLD := Color("e7ba72")
const WorldView = preload("res://scripts/cafe_view.gd")

var active_category: String = "All"
var search_query: String = ""
var selected_request: String = ""
var sound_on: bool = true
var motion_off: bool = false
var _screen: String = "ORDER"
var _menu_grid: GridContainer
var _cart_list: VBoxContainer
var _tickets: Dictionary = {}
var _request_list: VBoxContainer
var _category_buttons: Dictionary = {}
var _patience: Dictionary = {}
var _name: LineEdit
var _table: LineEdit
var _total: Label
var _cart_count: Label
var _status: Label
var _xp: Label
var _served: Label
var _clock: Label
var _goal: ProgressBar
var _send: Button
var _order_page: HBoxContainer
var _kitchen_page: HBoxContainer
var _tab_order: Button
var _tab_kitchen: Button
var _world: Control
var _restart: ConfirmationDialog
var _reset: ConfirmationDialog
var _results: ConfirmationDialog
var _options: AcceptDialog
var _audio: AudioStreamPlayer
var _next_mode: String = "RUSH"
var _refresh_pending: bool = false
var _shown_result: String = ""

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _build_ui()
    OrderStore.cart_changed.connect(_schedule_refresh)
    OrderStore.orders_changed.connect(_schedule_refresh)
    OrderStore.game_changed.connect(_schedule_refresh)
    _audio = AudioStreamPlayer.new()
    add_child(_audio)
    _refresh_all()
    _tab_order.grab_focus()

func _process(_delta: float) -> void:
    _clock.text = "%02d:%02d" % [int(ceil(OrderStore.shift.remaining)) / 60, int(ceil(OrderStore.shift.remaining)) % 60] if OrderStore.shift.mode == "RUSH" else "NO TIMER"
    _served.text = "%d / 5 served" % OrderStore.shift.served
    _xp.text = "%d XP  ·  Lv %d" % [OrderStore.xp, 1 + OrderStore.xp / 150]
    _goal.value = mini(5, OrderStore.shift.served)
    for id in _patience.keys():
        var request: Dictionary = OrderStore.shift.find_request(id)
        if not request.is_empty() and is_instance_valid(_patience[id]):
            _patience[id].value = float(request["patience"])
    if not OrderStore.shift.result.is_empty() and _shown_result != OrderStore.shift.result:
        _shown_result = OrderStore.shift.result
        _results.title = "A shift to remember!" if _shown_result == "SUCCESS" else "That's the afternoon rush!"
        _results.dialog_text = "%d / 5 requests served\n%d shift XP · Rs %d earned\n%d customers left before ordering\n\n%s" % [OrderStore.shift.served, OrderStore.shift.score, OrderStore.earnings, OrderStore.shift.missed,
            "Five happy tables. The regulars will be back." if _shown_result == "SUCCESS" else "Try welcoming fewer customers and clear the kitchen early."]
        _results.popup_centered(Vector2i(470,260))

func _schedule_refresh() -> void:
    if _refresh_pending:
        return
    _refresh_pending = true
    call_deferred("_refresh_all")

func _refresh_all() -> void:
    _refresh_pending = false
    _refresh_cart()
    _refresh_kitchen()
    _refresh_requests()

func _box(bg: Color = PAPER, border: Color = LINE, radius: int = 8, padding: int = 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.content_margin_left = padding
    s.content_margin_right = padding
    s.content_margin_top = padding
    s.content_margin_bottom = padding
    return s

func _panel(bg: Color = PAPER) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _box(bg))
    return p

func _label(value: String, font_size: int = 14, tint: Color = INK) -> Label:
    var l := Label.new()
    l.text = value
    l.add_theme_color_override("font_color", tint)
    l.add_theme_font_size_override("font_size", font_size)
    l.autowrap_mode = TextServer.AUTOWRAP_OFF
    return l

func _column(gap: int = 10) -> VBoxContainer:
    var c := VBoxContainer.new()
    c.add_theme_constant_override("separation", gap)
    return c

func _row(gap: int = 8) -> HBoxContainer:
    var r := HBoxContainer.new()
    r.add_theme_constant_override("separation", gap)
    return r

func _spacer() -> Control:
    var c := Control.new()
    c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return c

func _button(text: String, action: Callable, primary: bool = false, node_name: String = "") -> Button:
    var b := Button.new()
    b.text = text
    if not node_name.is_empty():
        b.name = node_name
    b.custom_minimum_size.y = 38
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    b.add_theme_font_size_override("font_size", 14)
    b.add_theme_color_override("font_color", PAPER if primary else INK)
    b.add_theme_color_override("font_hover_color", PAPER if primary else INK)
    b.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
    b.add_theme_color_override("font_disabled_color", MUTED)
    b.add_theme_stylebox_override("normal", _box(CORAL if primary else BG, CORAL if primary else LINE, 6, 9))
    b.add_theme_stylebox_override("hover", _box(Color("bd6653") if primary else Color("ecd5ae"), GOLD, 6, 9))
    b.add_theme_stylebox_override("pressed", _box(Color("8e4237") if primary else Color("dec59b"), GOLD, 6, 9))
    b.add_theme_stylebox_override("disabled", _box(Color("e8dcc7"), LINE, 6, 9))
    var focus: StyleBoxFlat = _box(Color(0,0,0,0), GREEN, 6, 9)
    focus.set_border_width_all(3)
    b.add_theme_stylebox_override("focus", focus)
    b.pressed.connect(func():
        _play("tap")
        action.call()
    )
    return b

func _input_field(placeholder: String, node_name: String) -> LineEdit:
    var field := LineEdit.new()
    field.name = node_name
    field.placeholder_text = placeholder
    field.custom_minimum_size.y = 38
    field.max_length = 28
    field.add_theme_stylebox_override("normal", _box(PAPER, LINE, 6, 8))
    field.add_theme_stylebox_override("focus", _box(PAPER, GREEN, 6, 8))
    field.add_theme_color_override("font_color", INK)
    field.add_theme_color_override("font_placeholder_color", MUTED)
    field.add_theme_color_override("caret_color", CORAL)
    field.add_theme_font_size_override("font_size", 14)
    return field

func _icon(id: String, icon_size: int = 48) -> TextureRect:
    var r := TextureRect.new()
    r.texture = load("res://assets/original/%s.png" % id)
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    r.custom_minimum_size = Vector2(icon_size,icon_size)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,18)
    add_child(margin)
    var page: VBoxContainer = _column(14)
    margin.add_child(page)
    page.add_child(_build_header())
    var body: HBoxContainer = _row(16)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(body)
    body.add_child(_build_cafe())
    var desk: VBoxContainer = _column(12)
    desk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(desk)
    var tabs: HBoxContainer = _row(8)
    desk.add_child(tabs)
    _tab_order = _button("01  THE TILL", func(): _switch_screen("ORDER"), true, "TabOrder")
    _tab_kitchen = _button("02  THE KITCHEN", func(): _switch_screen("KITCHEN"), false, "TabKitchen")
    tabs.add_child(_tab_order)
    tabs.add_child(_tab_kitchen)
    tabs.add_child(_spacer())
    tabs.add_child(_button("Connect devices", _open_sync, false, "OpenSync"))
    _order_page = _build_order_desk()
    _order_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
    desk.add_child(_order_page)
    _kitchen_page = _build_kitchen()
    _kitchen_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
    desk.add_child(_kitchen_page)
    _kitchen_page.hide()
    var footer: HBoxContainer = _row()
    footer.add_child(_label("●  CAFÉ SHIFT",12,GREEN))
    _status = _label("Welcome in. Select a customer, read their request, and build their order.",13,MUTED)
    _status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(_status)
    footer.add_child(_button("Options",func(): _options.popup_centered(Vector2i(400,240)),false,"Options"))
    page.add_child(footer)
    _build_dialogs()

func _build_header() -> PanelContainer:
    var p: PanelContainer = _panel(Color("493a39"))
    var row: HBoxContainer = _row(14)
    p.add_child(row)
    row.add_child(_icon("latte",56))
    var brand: VBoxContainer = _column(0)
    brand.custom_minimum_size.x = 230
    brand.add_child(_label("CAFÉ SHIFT",29,PAPER))
    brand.add_child(_label("R U S H  H O U R",11,GOLD))
    row.add_child(brand)
    row.add_child(_spacer())
    var goal: VBoxContainer = _column(3)
    goal.custom_minimum_size.x = 190
    _served = _label("0 / 5 served",17,PAPER)
    goal.add_child(_served)
    _goal = ProgressBar.new()
    _goal.max_value = 5
    _goal.show_percentage = false
    _goal.custom_minimum_size.y = 7
    _goal.add_theme_stylebox_override("background",_box(Color("66534d"),Color("66534d"),2,0))
    _goal.add_theme_stylebox_override("fill",_box(GOLD,GOLD,2,0))
    goal.add_child(_goal)
    row.add_child(goal)
    _clock = _label("NO TIMER",20,GOLD)
    _clock.custom_minimum_size.x = 115
    row.add_child(_clock)
    _xp = _label("0 XP · Lv 1",16,PAPER)
    _xp.custom_minimum_size.x = 150
    row.add_child(_xp)
    return p

func _build_cafe() -> VBoxContainer:
    var side: VBoxContainer = _column(10)
    side.custom_minimum_size.x = 430
    side.size_flags_horizontal = Control.SIZE_FILL
    var title: HBoxContainer = _row()
    title.add_child(_label("A little café, a lovely afternoon.",20,INK))
    side.add_child(title)
    side.add_child(_label("Read the request  →  ring it up  →  serve it warm",13,MUTED))
    _world = WorldView.new()
    _world.custom_minimum_size = Vector2(430,322)
    side.add_child(_world)
    var modes: HBoxContainer = _row(8)
    modes.add_child(_button("Free Play",func(): _ask_shift("FREE"),false,"FreePlay"))
    modes.add_child(_button("Rush Hour · 3:00",func(): _ask_shift("RUSH"),true,"RushHour"))
    side.add_child(modes)
    var heading: HBoxContainer = _row()
    heading.add_child(_label("THE REGULARS",13,GREEN))
    heading.add_child(_spacer())
    heading.add_child(_button("+ Welcome",func(): OrderStore.welcome_customer(),false,"Welcome"))
    side.add_child(heading)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    side.add_child(scroll)
    _request_list = _column(8)
    _request_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_request_list)
    return side

func _build_order_desk() -> HBoxContainer:
    var row: HBoxContainer = _row(12)
    var menu: VBoxContainer = _column(10)
    menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(menu)
    menu.add_child(_label("Made with a little love.",23))
    var search: LineEdit = _input_field("Search the menu…","Search")
    search.max_length = 80
    search.text_changed.connect(func(value: String):
        search_query = value
        _refresh_menu()
    )
    menu.add_child(search)
    var categories: HBoxContainer = _row(4)
    for category in ["All","Coffee","Tea","Bites","Desserts"]:
        var value: String = category
        var b: Button = _button(value,func(): _select_category(value),false,"Category"+value)
        b.add_theme_font_size_override("font_size",12)
        _category_buttons[value] = b
        categories.add_child(b)
    menu.add_child(categories)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    menu.add_child(scroll)
    _menu_grid = GridContainer.new()
    _menu_grid.columns = 2
    _menu_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _menu_grid.add_theme_constant_override("h_separation",8)
    _menu_grid.add_theme_constant_override("v_separation",8)
    scroll.add_child(_menu_grid)
    _refresh_menu()
    var receipt: PanelContainer = _panel()
    receipt.custom_minimum_size.x = 290
    row.add_child(receipt)
    var cart: VBoxContainer = _column(9)
    receipt.add_child(cart)
    cart.add_child(_label("Your order",23))
    _cart_count = _label("0 items · made fresh",12,MUTED)
    cart.add_child(_cart_count)
    cart.add_child(_label("CUSTOMER / TABLE",11,GREEN))
    _name = _input_field("Guest name (optional)","CustomerName")
    _table = _input_field("Table or takeaway","Table")
    cart.add_child(_name)
    cart.add_child(_table)
    var scroll_cart := ScrollContainer.new()
    scroll_cart.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll_cart.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cart.add_child(scroll_cart)
    _cart_list = _column(8)
    _cart_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_cart.add_child(_cart_list)
    cart.add_child(HSeparator.new())
    _total = _label("TOTAL     Rs 0",22)
    cart.add_child(_total)
    cart.add_child(_label("No real payments. Just good coffee.",11,MUTED))
    _send = _button("Send to kitchen  →",_place_order,true,"SendOrder")
    _send.custom_minimum_size.y = 46
    cart.add_child(_send)
    cart.add_child(_button("Clear cart",func(): OrderStore.clear_cart(),false,"ClearCart"))
    return row

func _refresh_menu() -> void:
    _clear(_menu_grid)
    for product in OrderStore.MENU:
        if active_category != "All" and str(product["category"]) != active_category:
            continue
        if not search_query.strip_edges().is_empty() and not (str(product["name"])+" "+str(product["description"])).to_lower().contains(search_query.to_lower().strip_edges()):
            continue
        var card: PanelContainer = _panel()
        card.custom_minimum_size = Vector2(185,150)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var column: VBoxContainer = _column(4)
        card.add_child(column)
        var top: HBoxContainer = _row(5)
        top.add_child(_icon(str(product["id"]),42))
        var name: Label = _label(str(product["name"]),15)
        name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        top.add_child(name)
        column.add_child(top)
        var description: Label = _label(str(product["description"]),12,MUTED)
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.custom_minimum_size.x = 150
        column.add_child(description)
        var fill := Control.new()
        fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
        column.add_child(fill)
        var bottom: HBoxContainer = _row(5)
        bottom.add_child(_label("Rs %d" % int(product["price"]),17,CORAL))
        bottom.add_child(_spacer())
        var id: String = str(product["id"])
        bottom.add_child(_button("+ Add",func(): OrderStore.add_item(id),false,"Add_"+id))
        column.add_child(bottom)
        _menu_grid.add_child(card)
    if _menu_grid.get_child_count() == 0:
        _menu_grid.add_child(_label("No matches. Try another search or category.",14,MUTED))

func _select_category(category: String) -> void:
    active_category = category
    for value in _category_buttons:
        _category_buttons[value].add_theme_stylebox_override("normal",_box(GOLD if value == category else BG,LINE,6,9))
    _refresh_menu()

func _refresh_cart() -> void:
    if not is_instance_valid(_cart_list):
        return
    _clear(_cart_list)
    _cart_count.text = "%d items · made fresh" % OrderStore.cart_item_count()
    _total.text = "TOTAL     Rs %d" % OrderStore.cart_total()
    _send.disabled = OrderStore.cart.is_empty() or (OrderStore.shift.mode == "RUSH" and not OrderStore.shift.active)
    if OrderStore.cart.is_empty():
        _cart_list.add_child(_icon("croissant",70))
        _cart_list.add_child(_label("A fresh start.\nAdd something from the menu.",14,MUTED))
    for id in OrderStore.cart:
        var product: Dictionary = OrderStore.find_product(id)
        var count: int = int(OrderStore.cart[id])
        var p: PanelContainer = _panel(BG)
        var c: VBoxContainer = _column(5)
        p.add_child(c)
        c.add_child(_label(str(product["name"]),14))
        var r: HBoxContainer = _row(5)
        r.add_child(_label("Rs %d" % (int(product["price"])*count),13,CORAL))
        r.add_child(_spacer())
        var product_id: String = str(id)
        r.add_child(_button("−",func(): OrderStore.change_quantity(product_id,-1),false,"Minus_"+product_id))
        r.add_child(_label(str(count),14))
        r.add_child(_button("+",func(): OrderStore.change_quantity(product_id,1),false,"Plus_"+product_id))
        c.add_child(r)
        _cart_list.add_child(p)

func _refresh_requests() -> void:
    _clear(_request_list)
    _patience.clear()
    if not OrderStore.shift.find_request(selected_request).is_empty():
        if str(OrderStore.shift.find_request(selected_request)["state"]) != "WAITING":
            selected_request = ""
    else:
        selected_request = ""
    for request in OrderStore.shift.requests:
        var id: String = str(request["id"])
        var p: PanelContainer = _panel(Color("e4ecd6") if selected_request == id else PAPER)
        var r: HBoxContainer = _row(8)
        p.add_child(r)
        var portrait := TextureRect.new()
        var path: String = "res://assets/licensed/%s_idle_anim.png" % str(request["name"])
        if ResourceLoader.exists(path):
            var atlas := AtlasTexture.new()
            atlas.atlas = load(path)
            atlas.region = Rect2(0,0,16,32)
            portrait.texture = atlas
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.custom_minimum_size = Vector2(32,64)
        r.add_child(portrait)
        var info: VBoxContainer = _column(3)
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.add_child(_label("%s · Table %s" % [request["name"],request["table"]],15))
        var lines: PackedStringArray = []
        for key in request["recipe"]:
            lines.append("%d × %s" % [int(request["recipe"][key]),OrderStore.find_product(key)["name"]])
        var description: Label = _label(" + ".join(lines),12,MUTED)
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.custom_minimum_size.x = 175
        info.add_child(description)
        if OrderStore.shift.mode == "RUSH":
            var patience := ProgressBar.new()
            patience.max_value = 65
            patience.value = request["patience"]
            patience.show_percentage = false
            patience.tooltip_text = "Patience: order before the bar runs out."
            patience.custom_minimum_size.y = 6
            patience.add_theme_stylebox_override("background",_box(LINE,LINE,2,0))
            patience.add_theme_stylebox_override("fill",_box(GREEN,GREEN,2,0))
            info.add_child(patience)
            _patience[id] = patience
        r.add_child(info)
        if str(request["state"]) == "WAITING":
            r.add_child(_button("Selected" if selected_request == id else "Take order",func(): _select_request(id),selected_request == id,"Request_"+id))
        else:
            r.add_child(_label("In kitchen\n#%s" % request["order_id"],12,GREEN))
        _request_list.add_child(p)
    if OrderStore.shift.requests.is_empty():
        _request_list.add_child(_label("A quiet moment. Welcome a customer, or try a new shift.",14,MUTED))

func _select_request(id: String) -> void:
    selected_request = id
    var request: Dictionary = OrderStore.shift.find_request(id)
    _name.text = str(request["name"])
    _table.text = str(request["table"])
    _notify("%s's order is selected. Match their request using the menu." % request["name"])
    _refresh_requests()
    _switch_screen("ORDER")

func _place_order() -> void:
    var id: int = OrderStore.place_order(_name.text,_table.text,selected_request)
    if id < 0:
        _play("error")
        _notify(OrderStore.last_error)
        return
    _play("order")
    selected_request = ""
    _name.clear()
    _table.clear()
    _notify("Ticket #%d printed. Open the kitchen to start preparing." % id)

func _build_kitchen() -> HBoxContainer:
    var board: HBoxContainer = _row(8)
    for status in ["NEW","PREPARING","DONE"]:
        var p: PanelContainer = _panel()
        p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var c: VBoxContainer = _column(10)
        p.add_child(c)
        c.add_child(_label({"NEW":"01  NEW","PREPARING":"02  PREPARING","DONE":"03  DONE"}[status],14,GREEN))
        var scroll := ScrollContainer.new()
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        c.add_child(scroll)
        var tickets: VBoxContainer = _column(10)
        tickets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(tickets)
        _tickets[status] = tickets
        board.add_child(p)
    return board

func _refresh_kitchen() -> void:
    for status in _tickets:
        _clear(_tickets[status])
    for order in OrderStore.orders:
        var p: PanelContainer = _panel(BG)
        var c: VBoxContainer = _column(8)
        p.add_child(c)
        var id: int = int(order["id"])
        c.add_child(_label("#%d · %s" % [id,order.get("customer","Guest")],18))
        c.add_child(_label("TABLE %s" % order.get("table","Takeaway"),11,MUTED))
        c.add_child(HSeparator.new())
        for line in order["items"]:
            c.add_child(_label("%d × %s" % [int(line["qty"]),line["name"]],14))
        c.add_child(_label("Rs %d" % int(order["total"]),17,CORAL))
        if str(order["status"]) == "DONE":
            c.add_child(_label("✓ SERVED  +%d XP" % int(order.get("xp",25)),13,GREEN))
        else:
            c.add_child(_button("Start preparing" if str(order["status"]) == "NEW" else "Mark done ✓",func(): _advance(id),true,"Advance_%d" % id))
        _tickets[order["status"]].add_child(p)
    for status in _tickets:
        if _tickets[status].get_child_count() == 0:
            var empty: Label = _label({"NEW":"The printer is quiet.\nOrders appear here as soon as they're sent.","PREPARING":"Room on the counter.\nStart a new ticket to get cooking.","DONE":"Happy tables ahead.\nFinish a ticket to earn XP."}[status],14,MUTED)
            empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            _tickets[status].add_child(empty)

func _advance(id: int) -> void:
    if OrderStore.advance_order(id):
        _play("done")
        _notify("Ticket #%d updated. %d served · Rs %d earned." % [id,OrderStore.served_count,OrderStore.earnings])

func _switch_screen(value: String) -> void:
    _screen = value
    _order_page.visible = value == "ORDER"
    _kitchen_page.visible = value == "KITCHEN"
    _tab_order.add_theme_stylebox_override("normal",_box(GOLD if value == "ORDER" else BG,LINE,6,9))
    _tab_order.add_theme_color_override("font_color",INK)
    _tab_kitchen.add_theme_stylebox_override("normal",_box(GOLD if value == "KITCHEN" else BG,LINE,6,9))
    if not motion_off:
        var target: Control = _order_page if value == "ORDER" else _kitchen_page
        target.modulate.a = 0.5
        create_tween().tween_property(target,"modulate:a",1.0,0.18)

func _notify(message: String) -> void:
    _status.text = message

func _play(id: String) -> void:
    if sound_on and is_instance_valid(_audio):
        _audio.stream = load("res://assets/original/%s.wav" % id)
        _audio.play()

func _ask_shift(mode: String) -> void:
    _next_mode = mode
    _restart.dialog_text = "Start %s? Current tickets and cart will be cleared. Your lifetime XP stays.\n\n%s" % ["Rush Hour" if mode == "RUSH" else "Free Play","Serve five exact customer requests in three minutes. Keep an eye on patience!" if mode == "RUSH" else "No clock, no pressure. Explore the till and kitchen at your pace."]
    _restart.popup_centered(Vector2i(440,230))

func _start_shift() -> void:
    _shown_result = ""
    selected_request = ""
    OrderStore.start_shift(_next_mode)
    _name.clear()
    _table.clear()
    _switch_screen("ORDER")
    _notify("Serve five regulars before 3:00. Choose a customer to begin." if _next_mode == "RUSH" else "Free Play. Select a regular, or enter a custom guest order.")
    _tab_order.grab_focus()

func _build_dialogs() -> void:
    _restart = ConfirmationDialog.new()
    _restart.name = "RestartDialog"
    _restart.title = "A fresh shift"
    _restart.confirmed.connect(_start_shift)
    add_child(_restart)
    _reset = ConfirmationDialog.new()
    _reset.name = "ResetDialog"
    _reset.title = "Reset all progress?"
    _reset.dialog_text = "Clear tickets, cart, earnings and lifetime XP on this device?"
    _reset.confirmed.connect(func():
        OrderStore.reset_demo()
        selected_request = ""
        _shown_result = ""
        _notify("A clean slate. Welcome back!")
    )
    add_child(_reset)
    _results = ConfirmationDialog.new()
    _results.name = "ResultsDialog"
    _results.get_ok_button().text = "Another rush"
    _results.get_cancel_button().text = "Keep exploring"
    _results.confirmed.connect(func():
        _next_mode = "RUSH"
        _start_shift()
    )
    add_child(_results)
    _options = AcceptDialog.new()
    _options.name = "OptionsDialog"
    _options.title = "Make yourself comfortable"
    var c: VBoxContainer = _column(12)
    _options.add_child(c)
    var sound := CheckButton.new()
    sound.text = "Sound effects"
    sound.button_pressed = sound_on
    sound.toggled.connect(func(value: bool): sound_on = value)
    sound.name = "SoundToggle"
    c.add_child(sound)
    var motion := CheckButton.new()
    motion.text = "Reduce motion"
    motion.name = "MotionToggle"
    motion.toggled.connect(func(value: bool):
        motion_off = value
        _world.reduced_motion = value
    )
    c.add_child(motion)
    c.add_child(_label("LimeZu · Modern Interiors\nOriginal café layout, icons and chimes.\nAI-assisted code; see README for details.",12,MUTED))
    c.add_child(_button("Reset all progress…",func():
        _options.hide()
        _reset.popup_centered()
    ,false,"ResetProgress"))
    add_child(_options)

func _open_sync() -> void:
    _notify("Online service is being configured. Offline orders are saved here.")
