extends Control
## Native Godot UI; stable form fields survive cart and kitchen updates.

const BG := Color("211b22")
const PAPER := Color("fff3d2")
const INK := Color("493a39")
const MUTED := Color("b9a28f")
const LINE := Color("6c5149")
const CORAL := Color("c86652")
const GREEN := Color("6da18b")
const GOLD := Color("e7ba72")
const WOOD := Color("3a2b2b")
const WorldView = preload("res://scripts/cafe_view.gd")
const BrewMeter = preload("res://scripts/pour_meter.gd")

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
var _request_prompt: Label
var _walk_in: Button
var _category_buttons: Dictionary = {}
var _patience: Dictionary = {}
var _patience_labels: Dictionary = {}
var _patience_colors: Dictionary = {}
var _brew_meters: Dictionary = {}
var _brew_hints: Dictionary = {}
var _brew_started: Dictionary = {}
var _flash_pending: Dictionary = {}
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
var _order_page: BoxContainer
var _kitchen_page: BoxContainer
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
var _last_missed: int = 0
var _sync_dialog: AcceptDialog
var _sync_endpoint: LineEdit
var _sync_input: LineEdit
var _sync_code: LineEdit
var _sync_status: Label
var _submitted_cart: Dictionary = {}
var _clipboard_success: JavaScriptObject
var _clipboard_failure: JavaScriptObject
var _phone_mode: bool = false
var _margin: MarginContainer
var _header_row: HBoxContainer
var _brand: VBoxContainer
var _floor_tag: Label
var _goal_box: VBoxContainer
var _tabs: HBoxContainer
var _btn_options: Button
var _btn_sync: Button
var _stage_row: BoxContainer
var _queue_panel: PanelContainer
var _menu_column: VBoxContainer
var _cart_scroll: ScrollContainer
var _receipt_panel: PanelContainer
var _kitchen_columns: Array[PanelContainer] = []
var _sync_box: VBoxContainer
var _sync_help: Label

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _build_ui()
    get_window().size_changed.connect(_update_layout)
    _update_layout()
    if OS.has_feature("web"):
        _clipboard_success = JavaScriptBridge.create_callback(_clipboard_pasted)
        _clipboard_failure = JavaScriptBridge.create_callback(_clipboard_denied)
    OrderStore.cart_changed.connect(_schedule_refresh)
    OrderStore.orders_changed.connect(_schedule_refresh)
    OrderStore.game_changed.connect(_schedule_refresh)
    KitchenSync.changed.connect(_on_sync_changed)
    KitchenSync.order_sent.connect(_on_online_sent)
    _audio = AudioStreamPlayer.new()
    add_child(_audio)
    _last_missed = OrderStore.shift.missed
    _refresh_all()
    _select_first_waiting_request(false)
    _tab_order.grab_focus()

func _process(_delta: float) -> void:
    _clock.text = "ONLINE" if KitchenSync.active else ("%02d:%02d" % [int(ceil(OrderStore.shift.remaining)) / 60, int(ceil(OrderStore.shift.remaining)) % 60] if OrderStore.shift.mode == "RUSH" else "FREE PLAY")
    _served.text = "%d online ticket%s" % [KitchenSync.orders.size(),"" if KitchenSync.orders.size() == 1 else "s"] if KitchenSync.active else ("%d / 5 served" % OrderStore.shift.served if OrderStore.shift.mode == "RUSH" else "%d served today" % OrderStore.shift.served)
    _xp.text = "%d XP  ·  Lv %d" % [OrderStore.xp, 1 + OrderStore.xp / 150]
    _goal.visible = not KitchenSync.active and OrderStore.shift.mode == "RUSH"
    _goal.value = mini(5, OrderStore.shift.served)
    if not KitchenSync.active and OrderStore.shift.missed > _last_missed:
        var lost: int = OrderStore.shift.missed - _last_missed
        _last_missed = OrderStore.shift.missed
        _notify("%d guest%s left without ordering. Watch the red patience bar." % [lost, "" if lost == 1 else "s"])
        _play("error")
        if not selected_request.is_empty() and OrderStore.shift.find_request(selected_request).is_empty():
            selected_request = ""
            _name.clear()
            _table.clear()
            if _world.has_method("set_selected_request"):
                _world.set_selected_request("")
            _select_first_waiting_request(false)
            if selected_request.is_empty():
                _refresh_cart()
    for id in _patience.keys():
        var request: Dictionary = OrderStore.shift.find_request(id)
        if not request.is_empty() and is_instance_valid(_patience[id]):
            var seconds_left: int = maxi(0, ceili(float(request["patience"])))
            _patience[id].value = float(seconds_left)
            if is_instance_valid(_patience_labels.get(id)):
                _patience_labels[id].text = "%ds" % seconds_left
                var urgency_color: Color = CORAL if seconds_left <= 20 else GREEN
                _patience_labels[id].add_theme_color_override("font_color", CORAL if seconds_left <= 20 else MUTED)
                if _patience_colors.get(id, GREEN) != urgency_color:
                    _patience_colors[id] = urgency_color
                    _patience[id].add_theme_stylebox_override("fill", _box(urgency_color, urgency_color, 2, 0))
    for id in _brew_meters.keys():
        if is_instance_valid(_brew_hints.get(id)):
            _brew_hints[id].text = _brew_meters[id].quality_hint()
            _brew_hints[id].add_theme_color_override("font_color", GREEN if _brew_meters[id].quality_bonus() > 0 else MUTED)
    if not KitchenSync.active and not OrderStore.shift.result.is_empty() and _shown_result != OrderStore.shift.result:
        _shown_result = OrderStore.shift.result
        _results.title = "A shift to remember!" if _shown_result == "SUCCESS" else "That's the afternoon rush!"
        _results.dialog_text = "%d / 5 requests served\n%d shift XP · Rs %d earned\n%d customers left before ordering\n\n%s" % [OrderStore.shift.served, OrderStore.shift.score, OrderStore.earnings, OrderStore.shift.missed,
            "Five happy tables. The regulars will be back." if _shown_result == "SUCCESS" else "Try welcoming fewer customers and clear the kitchen early."]
        _results.popup_centered(Vector2i(400,280) if _phone_mode else Vector2i(470,260))

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

func _on_sync_changed() -> void:
    OrderStore.set_process(not KitchenSync.active)
    _sync_status.text = KitchenSync.status
    _sync_code.text = KitchenSync.kitchen_code
    _notify(KitchenSync.status)
    _schedule_refresh()
    if KitchenSync.active and KitchenSync.role == "KITCHEN":
        _switch_screen("KITCHEN")

func _on_online_sent(id: int) -> void:
    for key in _submitted_cart:
        OrderStore.change_quantity(key,-int(_submitted_cart[key]))
    _submitted_cart.clear()
    _name.clear()
    _table.clear()
    _play("order")
    _notify("Online ticket #%d accepted by the server." % id)

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
    b.add_theme_stylebox_override("normal", _box(CORAL if primary else Color("f1dfb9"), CORAL if primary else LINE, 6, 9))
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
    _margin = MarginContainer.new()
    _margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]:
        _margin.add_theme_constant_override("margin_"+side,14)
    add_child(_margin)
    var page: VBoxContainer = _column(10)
    _margin.add_child(page)
    page.add_child(_build_header())
    var body_scroll := ScrollContainer.new()
    body_scroll.name = "ShiftScroll"
    body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(body_scroll)
    var body: VBoxContainer = _column(8)
    body.custom_minimum_size.y = 660
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_scroll.add_child(body)
    body.add_child(_build_cafe())
    var desk: VBoxContainer = _column(8)
    desk.size_flags_vertical = Control.SIZE_FILL
    body.add_child(desk)
    _tabs = _row(8)
    desk.add_child(_tabs)
    _tab_order = _button("ORDER STATION", func(): _switch_screen("ORDER"), true, "TabOrder")
    _tab_kitchen = _button("KITCHEN RAIL", func(): _switch_screen("KITCHEN"), false, "TabKitchen")
    _tabs.add_child(_tab_order)
    _tabs.add_child(_tab_kitchen)
    _tabs.add_child(_spacer())
    _btn_options = _button("Options",func(): _options.popup_centered(Vector2i(400,240)),false,"Options")
    _tabs.add_child(_btn_options)
    _btn_sync = _button("Connect devices", _open_sync, false, "OpenSync")
    _tabs.add_child(_btn_sync)
    _order_page = _build_order_desk()
    _order_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
    desk.add_child(_order_page)
    _kitchen_page = _build_kitchen()
    _kitchen_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
    desk.add_child(_kitchen_page)
    _kitchen_page.hide()
    _stabilize_desk_pages()
    var footer: HBoxContainer = _row()
    _status = _label("Welcome in. Select a customer, read their request, and build their order.",13,MUTED)
    _status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # Long status lines must wrap or they force the whole layout wider than a
    # phone viewport (454px), which clips the right edge on narrow screens.
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer.add_child(_status)
    page.add_child(footer)
    _build_dialogs()

func _stabilize_desk_pages() -> void:
    # Hidden pages contribute no minimum size, so switching tabs would let the
    # desk collapse and squeeze the kitchen columns. Reserve at least the order
    # page's height for the kitchen rail so both tabs share one desk layout.
    await get_tree().process_frame
    if not is_instance_valid(_order_page) or not is_instance_valid(_kitchen_page):
        return
    if _phone_mode:
        _kitchen_page.custom_minimum_size.y = 0
        return
    _kitchen_page.custom_minimum_size.y = maxf(
        _kitchen_page.custom_minimum_size.y,
        _order_page.get_combined_minimum_size().y)

func _update_layout() -> void:
    # Wide windows keep the full desk. Narrow windows (phones, small browser
    # windows) get a single-column arrangement and a hand-sized logical canvas
    # so text and touch targets stay readable instead of shrinking the desk.
    _phone_mode = DisplayServer.window_get_size().x < 800
    var window: Window = get_window()
    window.content_scale_size = Vector2i(430, 900) if _phone_mode else Vector2i(0, 0)
    var margin: int = 16 if _phone_mode else 14
    for side in ["left", "right", "top", "bottom"]:
        _margin.add_theme_constant_override("margin_" + side, margin)
    _floor_tag.visible = not _phone_mode
    _header_row.add_theme_constant_override("separation", 6 if _phone_mode else 12)
    _brand.custom_minimum_size.x = 96 if _phone_mode else 170
    _goal_box.custom_minimum_size.x = 90 if _phone_mode else 160
    _served.add_theme_font_size_override("font_size", 12 if _phone_mode else 14)
    _clock.custom_minimum_size.x = 60 if _phone_mode else 110
    _clock.add_theme_font_size_override("font_size", 15 if _phone_mode else 16)
    _xp.custom_minimum_size.x = 88 if _phone_mode else 120
    _xp.add_theme_font_size_override("font_size", 12 if _phone_mode else 14)
    for tab in [_tab_order, _tab_kitchen, _btn_options, _btn_sync]:
        tab.add_theme_font_size_override("font_size", 12 if _phone_mode else 14)
    _tabs.add_theme_constant_override("separation", 4 if _phone_mode else 8)
    _btn_sync.text = "Sync" if _phone_mode else "Connect devices"
    _stage_row.vertical = _phone_mode
    _world.custom_minimum_size = Vector2(0, 300) if _phone_mode else Vector2(560, 190)
    _queue_panel.custom_minimum_size = Vector2(0, 340) if _phone_mode else Vector2(315, 0)
    _order_page.vertical = _phone_mode
    _menu_column.custom_minimum_size.y = 500 if _phone_mode else 0
    _cart_scroll.custom_minimum_size.y = 200 if _phone_mode else 0
    _menu_grid.columns = 2 if _phone_mode else 3
    _receipt_panel.custom_minimum_size.x = 0 if _phone_mode else 290
    _kitchen_page.vertical = _phone_mode
    _kitchen_page.custom_minimum_size.y = 0 if _phone_mode else 320
    for column in _kitchen_columns:
        column.custom_minimum_size.y = 230 if _phone_mode else 0
    var sync_width: float = 340.0 if _phone_mode else 500.0
    _sync_box.custom_minimum_size.x = sync_width
    _sync_help.custom_minimum_size.x = sync_width
    _sync_status.custom_minimum_size.x = sync_width
    _update_tab_labels()
    _stabilize_desk_pages()

func _update_tab_labels() -> void:
    _tab_order.text = "ORDER" if _phone_mode else "ORDER STATION"
    var new_count: int = 0
    var visible_orders: Array[Dictionary] = KitchenSync.orders if KitchenSync.active else OrderStore.orders
    for order in visible_orders:
        if str(order["status"]) == "NEW":
            new_count += 1
    var base: String = "KITCHEN" if _phone_mode else "KITCHEN RAIL"
    _tab_kitchen.text = base if new_count == 0 else "%s · %d new" % [base, new_count]

func _build_header() -> PanelContainer:
    var p: PanelContainer = _panel(Color("2b2026"))
    p.custom_minimum_size.y = 62
    _header_row = _row(12)
    p.add_child(_header_row)
    _brand = _column(0)
    _brand.custom_minimum_size.x = 170
    _brand.add_child(_label("CAFÉ SHIFT",18,PAPER))
    _brand.add_child(_label("RUSH HOUR",10,GOLD))
    _header_row.add_child(_brand)
    _floor_tag = _label("THE FLOOR",11,MUTED)
    _header_row.add_child(_floor_tag)
    _header_row.add_child(_spacer())
    _goal_box = _column(3)
    _goal_box.custom_minimum_size.x = 160
    _served = _label("0 / 5 served",14,PAPER)
    _goal_box.add_child(_served)
    _goal = ProgressBar.new()
    _goal.max_value = 5
    _goal.show_percentage = false
    _goal.custom_minimum_size.y = 7
    _goal.add_theme_stylebox_override("background",_box(Color("66534d"),Color("66534d"),2,0))
    _goal.add_theme_stylebox_override("fill",_box(GOLD,GOLD,2,0))
    _goal_box.add_child(_goal)
    _header_row.add_child(_goal_box)
    _clock = _label("FREE PLAY",16,GOLD)
    _clock.custom_minimum_size.x = 110
    _header_row.add_child(_clock)
    _xp = _label("0 XP · Lv 1",14,PAPER)
    _xp.custom_minimum_size.x = 120
    _header_row.add_child(_xp)
    return p

func _build_cafe() -> PanelContainer:
    var stage: PanelContainer = _panel(WOOD)
    stage.add_theme_stylebox_override("panel", _box(WOOD, LINE, 8, 8))
    stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.custom_minimum_size.y = 240
    stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _stage_row = BoxContainer.new()
    _stage_row.add_theme_constant_override("separation",12)
    _stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(_stage_row)
    var scene_column: VBoxContainer = _column(4)
    scene_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scene_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scene_column.add_child(_label("THE CAFÉ FLOOR",11,GOLD))
    _world = WorldView.new()
    _world.custom_minimum_size = Vector2(560,190)
    _world.size_flags_vertical = Control.SIZE_EXPAND_FILL
    if _world.has_signal("customer_selected"):
        _world.customer_selected.connect(_select_request)
    scene_column.add_child(_world)
    _stage_row.add_child(scene_column)
    _queue_panel = _panel(Color("f6e5c4"))
    _queue_panel.custom_minimum_size.x = 315
    _queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var queue_column: VBoxContainer = _column(6)
    _queue_panel.add_child(queue_column)
    var heading: HBoxContainer = _row(5)
    heading.add_child(_label("THE QUEUE",13,INK))
    heading.add_child(_spacer())
    heading.add_child(_button("+ Welcome",_welcome_customer,false,"Welcome"))
    queue_column.add_child(heading)
    var queue_hint: Label = _label("Tap a guest to hear their order.",11,MUTED)
    queue_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    queue_column.add_child(queue_hint)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    queue_column.add_child(scroll)
    _request_list = _column(8)
    _request_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_request_list)
    _stage_row.add_child(_queue_panel)
    var modes: HBoxContainer = _row(6)
    modes.add_child(_button("Free Play",func(): _ask_shift("FREE"),false,"FreePlay"))
    modes.add_child(_button("Rush Hour · 3:00",func(): _ask_shift("RUSH"),true,"RushHour"))
    scene_column.add_child(modes)
    return stage

func _build_order_desk() -> BoxContainer:
    var row: BoxContainer = BoxContainer.new()
    row.add_theme_constant_override("separation",12)
    _menu_column = _column(10)
    _menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(_menu_column)
    _menu_column.add_child(_label("THE SHELF",15,GOLD))
    var search: LineEdit = _input_field("Search the menu…","Search")
    search.max_length = 80
    search.text_changed.connect(func(value: String):
        search_query = value
        _refresh_menu()
    )
    _menu_column.add_child(search)
    var categories: HBoxContainer = _row(4)
    for category in ["All","Coffee","Tea","Bites","Desserts"]:
        var value: String = category
        var b: Button = _button(value,func(): _select_category(value),false,"Category"+value)
        b.add_theme_font_size_override("font_size",12)
        _category_buttons[value] = b
        categories.add_child(b)
    _menu_column.add_child(categories)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _menu_column.add_child(scroll)
    _menu_grid = GridContainer.new()
    # Three shallow shelf slots keep the full menu visible in the active shift
    # instead of hiding products behind a dashboard-style scroll wall.
    _menu_grid.columns = 3
    _menu_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _menu_grid.add_theme_constant_override("h_separation",8)
    _menu_grid.add_theme_constant_override("v_separation",8)
    scroll.add_child(_menu_grid)
    _refresh_menu()
    _receipt_panel = _panel(Color("fff1d0"))
    _receipt_panel.custom_minimum_size.x = 290
    row.add_child(_receipt_panel)
    var cart: VBoxContainer = _column(7)
    _receipt_panel.add_child(cart)
    var cart_heading: HBoxContainer = _row(6)
    cart_heading.add_child(_label("COUNTER RECEIPT",15,INK))
    _cart_count = _label("0 items",12,MUTED)
    cart_heading.add_child(_cart_count)
    cart_heading.add_child(_spacer())
    _walk_in = _button("Walk-in",_select_walk_in,false,"WalkIn")
    _walk_in.tooltip_text = "Build a custom order in Free Play. Rush Hour uses guest requests."
    cart_heading.add_child(_walk_in)
    cart.add_child(cart_heading)
    cart.add_child(_label("CUSTOMER / TABLE",11,GREEN))
    _name = _input_field("Guest name (optional)","CustomerName")
    _table = _input_field("Table or takeaway","Table")
    cart.add_child(_name)
    cart.add_child(_table)
    _request_prompt = _label("Choose a regular on the left. Match their item list, then send the ticket.",12,MUTED)
    _request_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _request_prompt.custom_minimum_size.y = 42
    cart.add_child(_request_prompt)
    _cart_scroll = ScrollContainer.new()
    _cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _cart_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cart.add_child(_cart_scroll)
    _cart_list = _column(8)
    _cart_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _cart_scroll.add_child(_cart_list)
    cart.add_child(HSeparator.new())
    _total = _label("TOTAL     Rs 0",22)
    cart.add_child(_total)
    var actions: HBoxContainer = _row(6)
    actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _send = _button("Send ticket  >",_place_order,true,"SendOrder")
    _send.custom_minimum_size = Vector2(0,44)
    _send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(_send)
    var clear: Button = _button("Clear",func(): OrderStore.clear_cart(),false,"ClearCart")
    clear.custom_minimum_size = Vector2(58,44)
    actions.add_child(clear)
    cart.add_child(actions)
    return row

func _refresh_menu() -> void:
    _clear(_menu_grid)
    for product in OrderStore.MENU:
        if active_category != "All" and str(product["category"]) != active_category:
            continue
        if not search_query.strip_edges().is_empty() and not (str(product["name"])+" "+str(product["description"])).to_lower().contains(search_query.to_lower().strip_edges()):
            continue
        var card: PanelContainer = _panel(Color("f1dfb9"))
        card.custom_minimum_size = Vector2(118,62)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var column: VBoxContainer = _column(2)
        card.add_child(column)
        var top: HBoxContainer = _row(5)
        top.add_child(_icon(str(product["id"]),20))
        var name: Label = _label(str(product["name"]),11)
        name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        top.add_child(name)
        column.add_child(top)
        var fill := Control.new()
        fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
        column.add_child(fill)
        var bottom: HBoxContainer = _row(5)
        bottom.add_child(_label("Rs %d" % int(product["price"]),11,CORAL))
        bottom.add_child(_spacer())
        var id: String = str(product["id"])
        var add: Button = _button("ADD",func(): OrderStore.add_item(id),false,"Add_"+id)
        add.custom_minimum_size = Vector2(48,26)
        add.add_theme_font_size_override("font_size",11)
        bottom.add_child(add)
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
    _cart_count.text = "%d items" % OrderStore.cart_item_count()
    _total.text = "TOTAL     Rs %d" % OrderStore.cart_total()
    _walk_in.disabled = not KitchenSync.active and OrderStore.shift.mode == "RUSH"
    var request: Dictionary = OrderStore.shift.find_request(selected_request)
    var request_mismatch: bool = not KitchenSync.active and not selected_request.is_empty() and (request.is_empty() or not OrderStore.shift.matches(selected_request, OrderStore.cart))
    var rush_without_guest: bool = not KitchenSync.active and OrderStore.shift.mode == "RUSH" and selected_request.is_empty()
    _send.disabled = OrderStore.cart.is_empty() or (not KitchenSync.active and OrderStore.shift.mode == "RUSH" and not OrderStore.shift.active) or KitchenSync.busy or (KitchenSync.active and KitchenSync.role != "POS") or request_mismatch or rush_without_guest
    _send.text = "Send to kitchen  >" if KitchenSync.active or request.is_empty() else "Send %s's ticket  >" % request["name"]
    _update_request_prompt()
    if OrderStore.cart.is_empty():
        _cart_list.add_child(_icon("croissant",48))
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
    _patience_labels.clear()
    _patience_colors.clear()
    if KitchenSync.active:
        var note: Label = _label("CONNECTED SERVICE\n\nEnter a guest order at the till. Share the kitchen code with another device. Tickets synchronize automatically every two seconds.\n\nFree Play and Rush Hour are separate offline modes.",14,MUTED)
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _request_list.add_child(note)
        return
    if not OrderStore.shift.find_request(selected_request).is_empty():
        if str(OrderStore.shift.find_request(selected_request)["state"]) != "WAITING":
            selected_request = ""
    else:
        selected_request = ""
    if selected_request.is_empty() and is_instance_valid(_world) and _world.has_method("set_selected_request"):
        _world.set_selected_request("")
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
            patience.tooltip_text = "The guest leaves when this reaches zero."
            patience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            patience.custom_minimum_size.y = 6
            patience.add_theme_stylebox_override("background",_box(LINE,LINE,2,0))
            var patience_color: Color = CORAL if float(request["patience"]) <= 20 else GREEN
            patience.add_theme_stylebox_override("fill",_box(patience_color,patience_color,2,0))
            var urgency: HBoxContainer = _row(5)
            urgency.add_child(patience)
            var seconds: Label = _label("%ds" % ceili(float(request["patience"])),11,patience_color)
            urgency.add_child(seconds)
            info.add_child(urgency)
            _patience[id] = patience
            _patience_labels[id] = seconds
            _patience_colors[id] = patience_color
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
    if request.is_empty() or str(request["state"]) != "WAITING":
        selected_request = ""
        return
    _name.text = str(request["name"])
    _table.text = str(request["table"])
    if _world.has_method("set_selected_request"):
        _world.set_selected_request(id)
    _update_request_prompt()
    _notify("%s wants %s. Match the list in your order card." % [request["name"], _recipe_summary(request["recipe"])])
    _refresh_requests()
    _refresh_cart()
    _switch_screen("ORDER")

func _select_first_waiting_request(announce: bool = true) -> void:
    if KitchenSync.active or not selected_request.is_empty():
        return
    for request in OrderStore.shift.requests:
        if str(request["state"]) == "WAITING":
            if announce:
                _select_request(str(request["id"]))
            else:
                var id: String = str(request["id"])
                selected_request = id
                _name.text = str(request["name"])
                _table.text = str(request["table"])
                if _world.has_method("set_selected_request"):
                    _world.set_selected_request(id)
                    _refresh_requests()
                _refresh_cart()
            return

func _select_walk_in() -> void:
    if not KitchenSync.active and OrderStore.shift.mode == "RUSH":
        _notify("Rush Hour is all about serving the waiting regulars. Choose a guest on the left.")
        return
    selected_request = ""
    _name.clear()
    _table.clear()
    if _world.has_method("set_selected_request"):
        _world.set_selected_request("")
    _refresh_requests()
    _refresh_cart()
    _notify("Walk-in selected. Build any order from the menu.")

func _welcome_customer() -> void:
    var id: String = OrderStore.welcome_customer()
    if id.is_empty():
        _notify("The queue is full. Serve a guest before welcoming another.")
        return
    var request: Dictionary = OrderStore.shift.find_request(id)
    if selected_request.is_empty():
        _select_request(id)
    else:
        _notify("%s joined the queue. Choose them when you're ready." % request["name"])

func _recipe_summary(recipe: Dictionary) -> String:
    var lines: PackedStringArray = []
    for key in recipe:
        lines.append("%d x %s" % [int(recipe[key]), OrderStore.find_product(str(key))["name"]])
    return " + ".join(lines)

func _update_request_prompt() -> void:
    if not is_instance_valid(_request_prompt):
        return
    if KitchenSync.active:
        _request_prompt.text = "Shared tickets sync to the other device. This till can send custom guest orders."
        _request_prompt.add_theme_color_override("font_color", GREEN)
        return
    if selected_request.is_empty():
        if OrderStore.shift.mode == "RUSH":
            _request_prompt.text = "Choose a waiting regular on the left. Rush tickets must match their recipe exactly."
        else:
            _request_prompt.text = "Free Play: build any walk-in order, or take a regular's exact request for a service bonus."
        _request_prompt.add_theme_color_override("font_color", MUTED)
        return
    var request: Dictionary = OrderStore.shift.find_request(selected_request)
    if request.is_empty():
        _request_prompt.text = "That guest has left. Choose another regular on the left."
        _request_prompt.add_theme_color_override("font_color", CORAL)
        return
    var recipe: Dictionary = request["recipe"]
    var matched_count: int = 0
    var target_count: int = 0
    for key in recipe:
        var wanted: int = int(recipe[key])
        target_count += wanted
        matched_count += mini(wanted, int(OrderStore.cart.get(key, 0)))
    var extras: bool = false
    for key in OrderStore.cart:
        if int(OrderStore.cart[key]) > int(recipe.get(key, 0)):
            extras = true
    var progress: String = "%d/%d items packed" % [matched_count, target_count]
    if OrderStore.shift.matches(selected_request, OrderStore.cart):
        _request_prompt.text = "REQUEST  ·  %s\n%s\nPERFECT MATCH  ·  ready for the kitchen" % [request["name"], _recipe_summary(recipe)]
        _request_prompt.add_theme_color_override("font_color", GREEN)
    elif extras:
        _request_prompt.text = "REQUEST  ·  %s\n%s\n%s  ·  remove the extra item" % [request["name"], _recipe_summary(recipe), progress]
        _request_prompt.add_theme_color_override("font_color", CORAL)
    else:
        _request_prompt.text = "REQUEST  ·  %s\n%s\n%s  ·  use + Add on the menu" % [request["name"], _recipe_summary(recipe), progress]
        _request_prompt.add_theme_color_override("font_color", MUTED)

func _place_order() -> void:
    if KitchenSync.active:
        _submitted_cart = OrderStore.cart.duplicate()
        KitchenSync.submit(_submitted_cart,_name.text,_table.text)
        return
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

func _build_kitchen() -> BoxContainer:
    var board: BoxContainer = BoxContainer.new()
    board.add_theme_constant_override("separation",8)
    board.custom_minimum_size.y = 320 # one ticket card plus its timing meter must fit
    _kitchen_columns.clear()
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
        _kitchen_columns.append(p)
    return board

func _refresh_kitchen() -> void:
    _brew_meters.clear()
    _brew_hints.clear()
    for status in _tickets:
        _clear(_tickets[status])
    var visible_orders: Array[Dictionary] = KitchenSync.orders if KitchenSync.active else OrderStore.orders
    for order in visible_orders:
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
            c.add_child(_label("SERVED" if KitchenSync.active else "SERVED  +%d XP" % int(order.get("xp",25)),13,GREEN))
        else:
            var status: String = str(order["status"])
            if status == "PREPARING" and not KitchenSync.active:
                var meter: Control = BrewMeter.new()
                var key: String = str(id)
                if not _brew_started.has(key):
                    _brew_started[key] = float(Time.get_ticks_msec()) / 1000.0
                meter.set("elapsed", maxf(0.0, float(Time.get_ticks_msec()) / 1000.0 - float(_brew_started[key])))
                meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                c.add_child(_label("TIME THE POUR",11,GREEN))
                c.add_child(meter)
                var hint: Label = _label(str(meter.call("quality_hint")),11,MUTED)
                c.add_child(hint)
                _brew_meters[key] = meter
                _brew_hints[key] = hint
            var advance: Button = _button("Start preparing" if status == "NEW" else ("Mark done" if KitchenSync.active else "Serve ticket"),func(): _advance(id),true,"Advance_%d" % id)
            advance.disabled = KitchenSync.active and (KitchenSync.role != "KITCHEN" or KitchenSync.busy)
            c.add_child(advance)
        _tickets[order["status"]].add_child(p)
        if _flash_pending.has(id):
            p.modulate = _flash_pending[id]
            _flash_pending.erase(id)
            var flash: Tween = p.create_tween()
            flash.tween_property(p,"modulate",Color.WHITE,0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    for status in _tickets:
        if _tickets[status].get_child_count() == 0:
            var empty: Label = _label({"NEW":"The printer is quiet.\nOrders appear here as soon as they're sent.","PREPARING":"Room on the counter.\nStart a new ticket to get cooking.","DONE":"Happy tables ahead.\nFinish a ticket to earn XP."}[status],14,MUTED)
            if status == "DONE" and KitchenSync.active:
                empty.text = "Happy tables ahead.\nCompleted tickets stay here."
            empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            _tickets[status].add_child(empty)
    _update_tab_labels()

func _advance(id: int) -> void:
    if KitchenSync.active:
        for order in KitchenSync.orders:
            if int(order["id"]) == id:
                KitchenSync.advance(id,str(order["status"]))
                return
    var quality: int = 0
    var key: String = str(id)
    var current_status: String = ""
    for order in OrderStore.orders:
        if int(order.get("id", -1)) == id:
            current_status = str(order.get("status", ""))
            break
    var served_request: String = ""
    if current_status == "PREPARING":
        for request in OrderStore.shift.requests:
            if int(request.get("order_id", -1)) == id:
                served_request = str(request["id"])
                break
    if current_status == "PREPARING" and _brew_meters.has(key):
        quality = _brew_meters[key].quality_bonus()
    var xp_before: int = OrderStore.xp
    if OrderStore.advance_order(id, quality):
        if current_status == "NEW":
            _brew_started[key] = float(Time.get_ticks_msec()) / 1000.0
            _flash_pending[id] = Color(1.6,1.55,1.4)
            _notify("Ticket #%d is on the counter. Watch the gold needle and serve in green for bonus XP." % id)
        else:
            _brew_started.erase(key)
            _flash_pending[id] = Color(1.85,1.6,0.95)
            _play("done")
            if not served_request.is_empty():
                _world.call("celebrate", served_request)
            var earned: int = OrderStore.xp - xp_before
            var quality_text: String = "Perfect pour! " if quality == 20 else ("Good pour! " if quality == 10 else "")
            _notify("%sTicket #%d served. +%d XP · Rs %d earned." % [quality_text,id,earned,OrderStore.earnings])

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
    if KitchenSync.active:
        _notify("Disconnect devices before starting an offline shift.")
        return
    _next_mode = mode
    _restart.dialog_text = "Start %s? Current tickets and cart will be cleared. Your lifetime XP stays.\n\n%s" % ["Rush Hour" if mode == "RUSH" else "Free Play","Serve five exact customer requests in three minutes. Keep an eye on patience!" if mode == "RUSH" else "No clock, no pressure. Explore the till and kitchen at your pace."]
    _restart.popup_centered(Vector2i(400,250) if _phone_mode else Vector2i(440,230))

func _style_dialog(dialog: AcceptDialog) -> void:
    var skin := Theme.new()
    skin.default_font_size = 14
    skin.set_stylebox("panel","AcceptDialog",_box(PAPER,LINE,8,16))
    var border: StyleBoxFlat = _box(INK,INK,8,12)
    border.expand_margin_top = 26
    skin.set_stylebox("embedded_border","Window",border)
    skin.set_color("title_color","Window",PAPER)
    skin.set_color("font_color","Label",INK)
    skin.set_color("font_color","Button",INK)
    skin.set_color("font_hover_color","Button",INK)
    skin.set_color("font_pressed_color","Button",INK)
    skin.set_stylebox("normal","Button",_box(BG,LINE,6,9))
    skin.set_stylebox("hover","Button",_box(Color("ecd5ae"),GOLD,6,9))
    skin.set_stylebox("pressed","Button",_box(Color("dec59b"),GOLD,6,9))
    dialog.theme = skin
    var ok: Button = dialog.get_ok_button()
    ok.custom_minimum_size = Vector2(90,38)
    ok.add_theme_stylebox_override("normal",_box(CORAL,CORAL,6,9))
    ok.add_theme_stylebox_override("hover",_box(Color("bd6653"),GOLD,6,9))
    ok.add_theme_color_override("font_color",PAPER)
    ok.add_theme_color_override("font_hover_color",PAPER)

func _start_shift() -> void:
    _shown_result = ""
    selected_request = ""
    OrderStore.start_shift(_next_mode)
    _last_missed = OrderStore.shift.missed
    _name.clear()
    _table.clear()
    if _world.has_method("set_selected_request"):
        _world.set_selected_request("")
    _switch_screen("ORDER")
    _notify("Rush is live. Match a request, send the ticket, then time your pour." if _next_mode == "RUSH" else "Free Play. Select a regular, or enter a custom guest order.")
    _select_first_waiting_request(false)
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
        for meter in _brew_meters.values():
            meter.set("reduced_motion", value)
    )
    c.add_child(motion)
    c.add_child(_label("LimeZu · Modern Interiors\nOriginal café layout, icons and chimes.\nAI-assisted code; see README for details.",12,MUTED))
    c.add_child(_button("Reset all progress…",func():
        _options.hide()
        _reset.popup_centered()
    ,false,"ResetProgress"))
    add_child(_options)
    _sync_dialog = AcceptDialog.new()
    _sync_dialog.name = "SyncDialog"
    _sync_dialog.title = "A till here. A kitchen over there."
    _sync_box = _column(10)
    _sync_box.custom_minimum_size.x = 500
    _sync_dialog.add_child(_sync_box)
    _sync_help = _label("Create a till room, then paste its kitchen code on a second device. Room credentials last seven days and are kept in memory. Keep the code private.",14,MUTED)
    _sync_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _sync_help.custom_minimum_size.x = 500
    _sync_box.add_child(_sync_help)
    _sync_status = _label(KitchenSync.status,14,GREEN)
    _sync_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _sync_status.custom_minimum_size.x = 500
    _sync_box.add_child(_sync_status)
    _sync_box.add_child(_label("SERVER",11,GREEN))
    _sync_endpoint = _input_field("HTTPS service URL","SyncEndpoint")
    _sync_endpoint.max_length = 200
    _sync_endpoint.text = KitchenSync.endpoint
    _sync_box.add_child(_sync_endpoint)
    _sync_box.add_child(_button("Create till room",func():
        if KitchenSync.configure(_sync_endpoint.text):
            KitchenSync.create_room()
    ,true,"CreateRoom"))
    _sync_box.add_child(_label("KITCHEN CODE FROM THIS TILL",11,GREEN))
    _sync_code = _input_field("Create a room to get its code","PairingCode")
    _sync_code.max_length = 120
    _sync_code.editable = false
    _sync_box.add_child(_sync_code)
    _sync_box.add_child(_button("Copy kitchen code",func():
        if not KitchenSync.kitchen_code.is_empty():
            DisplayServer.clipboard_set(KitchenSync.kitchen_code)
            _notify("Kitchen code copied. Share only with your kitchen device.")
    ,false,"CopyCode"))
    _sync_box.add_child(_label("JOIN AS KITCHEN",11,GREEN))
    _sync_input = _input_field("Paste the complete kitchen code","JoinCode")
    _sync_input.max_length = 120
    var join_row: HBoxContainer = _row()
    _sync_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    join_row.add_child(_sync_input)
    join_row.add_child(_button("Paste",_paste_code,false,"PasteCode"))
    _sync_box.add_child(join_row)
    _sync_box.add_child(_button("Join kitchen",func():
        if KitchenSync.configure(_sync_endpoint.text):
            KitchenSync.join_room(_sync_input.text)
    ,false,"JoinRoom"))
    _sync_box.add_child(_button("Disconnect · return to offline",func():
        KitchenSync.disconnect_room()
        _sync_input.clear()
        _sync_dialog.hide()
    ,false,"Disconnect"))
    add_child(_sync_dialog)
    for dialog in [_restart,_reset,_results,_options,_sync_dialog]:
        _style_dialog(dialog)

func _open_sync() -> void:
    _sync_dialog.popup_centered(Vector2i(400,660) if _phone_mode else Vector2i(550,570))

func _paste_code() -> void:
    if OS.has_feature("web"):
        var navigator: JavaScriptObject = JavaScriptBridge.get_interface("navigator")
        navigator.clipboard.readText().then(_clipboard_success,_clipboard_failure)
    else:
        _clipboard_pasted([DisplayServer.clipboard_get()])

func _clipboard_pasted(arguments: Array) -> void:
    if arguments.is_empty():
        return
    _sync_input.text = str(arguments[0]).strip_edges().left(120)
    _sync_input.grab_focus()
    _notify("Kitchen code pasted. Choose Join kitchen to connect.")

func _clipboard_denied(_arguments: Array) -> void:
    _notify("Clipboard access was declined. Paste with your browser's keyboard shortcut.")
