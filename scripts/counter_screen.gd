extends Control
## Scene-local coordinator: guests > individual preparation > tray > handoff.
signal desk_requested
const CounterTheme = preload("res://scripts/counter_theme.gd")
const Prep = preload("res://scripts/preparation.gd")
const Recipes = preload("res://scripts/recipes.gd")
var world: Control
var bench: Control
var slip: VBoxContainer
var menu: Control
var audio: Node
var tray: Button
var hud: Label
var cue: Label
var pause_button: Button
var selected_request: String = ""
var order_id: int = -1
var selected_product: String = ""
var preparation: RefCounted
var carrying: bool = false
var delivering: bool = false
var paused: bool = true
var _report_shown: bool = false

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var background := ColorRect.new()
    background.color = Color("30252b")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    world = preload("res://scripts/cafe_view.gd").new()
    world.allow_kitchen_selection = true
    world.spread_guests = true
    world.show_order_bubble = false
    world.customer_selected.connect(select_guest)
    add_child(world)
    bench = preload("res://scripts/prep_bench.gd").new()
    add_child(bench)
    slip = preload("res://scripts/order_slip.gd").new()
    slip.product_selected.connect(select_product)
    add_child(slip)
    hud = CounterTheme.label("", 18)
    add_child(hud)
    pause_button = CounterTheme.button("Menu", func(): set_paused(true), "CounterMenu")
    add_child(pause_button)
    cue = CounterTheme.label("Tap a guest to hear their order.", 18)
    cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(cue)
    tray = CounterTheme.button("The tray is empty", _pick_up, "ServingTray")
    tray.add_theme_font_size_override("font_size", 19)
    add_child(tray)
    audio = preload("res://scripts/counter_audio.gd").new()
    add_child(audio)
    menu = preload("res://scripts/counter_menu.gd").new()
    menu.persistence_enabled = OrderStore.persistence_enabled
    menu.resumed.connect(func(): set_paused(false))
    menu.mode_requested.connect(start_mode)
    menu.desk_requested.connect(func(): desk_requested.emit())
    menu.settings_changed.connect(_settings)
    add_child(menu)
    resized.connect(_layout)
    _layout()
    _settings(menu.sound.button_pressed, menu.motion.button_pressed)
    OrderStore.orders_changed.connect(_refresh)
    OrderStore.game_changed.connect(_refresh)
    for request in OrderStore.shift.requests:
        if str(request["state"]) == "KITCHEN":
            select_guest(str(request["id"]))
            break
    set_paused(true)

func _layout() -> void:
    if bench == null:
        return
    var portrait: bool = size.x < 700
    hud.position = Vector2(16, 12)
    hud.size = Vector2(size.x - 110, 42)
    hud.add_theme_font_size_override("font_size", 15 if portrait else 20)
    pause_button.position = Vector2(size.x - 90, 6)
    pause_button.size = Vector2(76, 54)
    var compact_landscape: bool = not portrait and size.y < 560
    cue.visible = not compact_landscape
    if compact_landscape:
        world.position = Vector2(10, 62)
        world.size = Vector2(size.x * 0.4 - 24, size.y - 240)
        slip.position = Vector2(14, size.y - 162)
        slip.size = Vector2(size.x * 0.4 - 28, 80)
        bench.position = Vector2(size.x * 0.4, 62)
        bench.size = Vector2(size.x * 0.6 - 18, size.y - 148)
    elif portrait:
        var stage_height: float = size.y * 0.23
        world.position = Vector2(4, 60)
        world.size = Vector2(size.x - 8, stage_height)
        slip.position = Vector2(12, 68 + stage_height)
        slip.size = Vector2(size.x - 24, 90)
        bench.position = Vector2(12, 166 + stage_height)
        bench.size = Vector2(size.x - 24, size.y - bench.position.y - 142)
    else:
        world.position = Vector2(10, 66)
        world.size = Vector2(size.x * 0.52 - 24, size.y - 210)
        slip.position = Vector2(size.x * 0.52, 78)
        slip.size = Vector2(size.x * 0.48 - 18, 86)
        bench.position = Vector2(size.x * 0.52, 174)
        bench.size = Vector2(size.x * 0.48 - 18, size.y - 318)
    cue.position = Vector2(16, size.y - 127)
    cue.size = Vector2(size.x - 32, 48)
    cue.add_theme_font_size_override("font_size", 15 if portrait else 19)
    tray.position = Vector2(12, size.y - 73)
    tray.size = Vector2(size.x - 24, 58)

func _process(_delta: float) -> void:
    var rush: bool = OrderStore.shift.mode == "RUSH"
    var seconds: int = ceili(OrderStore.shift.remaining)
    hud.text = ("%d:%02d  ·  %d/5 served" % [seconds / 60, seconds % 60, OrderStore.shift.served]) if rush else "CAFÉ SHIFT  ·  PRACTICE"
    hud.text += "  ·  %d XP" % OrderStore.xp
    if not paused and not _report_shown and not OrderStore.shift.result.is_empty():
        _report_shown = true
        OrderStore.record_best()
        set_paused(true, true)
        if OrderStore.shift.result == "SUCCESS": audio.play_event("fanfare")
    if selected_request != "" and OrderStore.shift.find_request(selected_request).is_empty() and not delivering:
        selected_request = ""
        order_id = -1
        selected_product = ""
        preparation = null
        bench.bind(null)
        slip.show_order({}, "")
        carrying = false
        _refresh()

func set_paused(value: bool, report: bool = false) -> void:
    paused = value
    OrderStore.set_process(not value and not KitchenSync.active)
    bench.set_process(not value)
    if preparation != null: preparation.holding = false
    bench.dragging = false
    audio.set_enabled(menu.sound.button_pressed and not value)
    if value: menu.show_menu(report or not OrderStore.shift.active)
    else:
        menu.hide()
        if preparation != null: bench.grab_focus()
    _refresh()

func start_mode(mode: String) -> void:
    OrderStore.start_shift(mode)
    selected_request = ""
    order_id = -1
    preparation = null
    selected_product = ""
    carrying = false
    _report_shown = false
    bench.bind(null)
    slip.show_order({}, "")
    world.set_selected_request("")
    world.actors.clear()
    world.celebrations.clear()
    world.floats.clear()
    set_paused(false)

func select_guest(id: String) -> void:
    if delivering:
        return
    if _work_locked(): return
    if carrying:
        if id == selected_request: _deliver()
        else: cue.text = "This tray belongs to %s. Tap them to deliver it." % OrderStore.find_order(order_id).get("customer", "your guest")
        return
    var chosen: int = OrderStore.take_counter_request(id)
    if chosen < 0:
        return
    selected_request = id
    order_id = chosen
    world.set_selected_request(id)
    var order: Dictionary = OrderStore.find_order(order_id)
    bench.tray_order = order
    var found: String = ""
    for item in order["items"]:
        if int(order.get("crafted", {}).get(str(item["id"]), 0)) < int(item["qty"]):
            found = str(item["id"])
            break
    if not found.is_empty(): select_product(found)
    else:
        preparation = null
        selected_product = ""
        bench.bind(null)
    audio.play_event("tap")
    _refresh()

func select_product(product: String) -> void:
    if carrying or delivering:
        return
    if _work_locked(): return
    var order: Dictionary = OrderStore.find_order(order_id)
    if order.is_empty(): return
    var required: int = 0
    for item in order["items"]:
        if str(item["id"]) == product: required = int(item["qty"])
    if required == 0 or int(order.get("crafted", {}).get(product, 0)) >= required: return
    selected_product = product
    preparation = Prep.new()
    preparation.begin(product, order.get("preparations", {}).get(product, {}))
    preparation.activity_started.connect(func(): OrderStore.save_preparation(order_id, preparation.snapshot()))
    preparation.checkpoint.connect(_checkpoint)
    preparation.completed.connect(_crafted)
    bench.bind(preparation, str(OrderStore.find_product(product)["name"]))
    _refresh()

func _checkpoint() -> void:
    OrderStore.save_preparation(order_id, preparation.snapshot())
    audio.play_event("tap")

func _crafted() -> void:
    if OrderStore.record_crafted_item(order_id, selected_product, preparation.quality):
        audio.play_event("order")
    bench.bind(null)
    preparation = null
    var next: String = ""
    for item in OrderStore.find_order(order_id).get("items", []):
        if int(OrderStore.find_order(order_id).get("crafted", {}).get(str(item["id"]), 0)) < int(item["qty"]):
            next = str(item["id"])
            break
    selected_product = ""
    _refresh()
    if next != "": call_deferred("select_product", next)

func _refresh() -> void:
    if tray == null: return
    var order: Dictionary = OrderStore.find_order(order_id)
    bench.tray_order = order
    slip.show_order(order, selected_product)
    var ready: bool = OrderStore.tray_ready(order_id)
    tray.disabled = not ready or delivering
    var total: int = 0
    var done: int = 0
    for item in order.get("items", []):
        total += int(item["qty"])
        done += int(order.get("crafted", {}).get(str(item["id"]), 0))
    tray.text = ("Tray in hand · tap %s" % order.get("customer", "the guest")) if carrying else ("Pick up %s's tray  >" % order.get("customer", "your guest") if ready else "%d / %d on the tray · keep cooking" % [done, total])
    if order.is_empty(): tray.text = "Your tray is waiting for a guest"
    if selected_request.is_empty():
        cue.text = "Tap a guest in the café. Their request stays above your work surface."
    elif ready:
        cue.text = "Everything is ready. Pick up the tray, then tap %s in the café." % order.get("customer", "the guest")
    else:
        cue.text = "Make each requested item. You can switch guests or recipes before picking up a tray."
    pause_button.disabled = delivering

func _pick_up() -> void:
    if not OrderStore.tray_ready(order_id): return
    carrying = not carrying
    _refresh()
    if carrying:
        cue.text = "Tap %s in the café to hand over their tray. Tap the tray again to put it down." % OrderStore.find_order(order_id)["customer"]

func _deliver() -> void:
    if not OrderStore.tray_ready(order_id) or delivering: return
    delivering = true
    _refresh()
    var delivery := HBoxContainer.new()
    delivery.mouse_filter = Control.MOUSE_FILTER_IGNORE
    delivery.position = tray.position + Vector2(30, 0)
    for item in OrderStore.find_order(order_id)["items"]:
        var icon := TextureRect.new()
        icon.texture = Recipes.texture(str(item["id"]))
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.custom_minimum_size = Vector2(48, 48)
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        delivery.add_child(icon)
    add_child(delivery)
    var world_scale: float = minf(world.size.x / 256, world.size.y / 192)
    var target: Vector2 = world.position + (world.size - Vector2(256, 192) * world_scale) / 2
    target += ((world.actors.get(selected_request, {}).get("pos", Vector2(128, 128))) as Vector2) * world_scale
    var motion: Tween = create_tween()
    motion.tween_property(delivery, "position", target, 0.08 if world.reduced_motion else 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    await motion.finished
    delivery.queue_free()
    var xp_before: int = OrderStore.xp
    if OrderStore.deliver_crafted(order_id):
        world.celebrate(selected_request)
        world.float_text(selected_request, "+%d XP · thank you!" % (OrderStore.xp - xp_before), CounterTheme.GOLD)
        audio.play_event("done")
    carrying = false
    delivering = false
    selected_request = ""
    order_id = -1
    preparation = null
    bench.bind(null)
    _refresh()

func _settings(sound: bool, motion: bool) -> void:
    audio.set_enabled(sound and not paused)
    world.reduced_motion = motion

func _work_locked() -> bool:
    if preparation != null and (preparation.holding or preparation.running):
        preparation.feedback = "Finish the active pour or lift the hot batch before switching."
        return true
    return false

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE and not delivering:
            set_paused(not paused)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_G and not paused:
            var requests: Array[Dictionary] = OrderStore.shift.requests
            if not requests.is_empty():
                var next: int = 0
                for i in range(requests.size()):
                    if str(requests[i]["id"]) == selected_request: next = (i + 1) % requests.size()
                select_guest(str(requests[next]["id"]))
                get_viewport().set_input_as_handled()
