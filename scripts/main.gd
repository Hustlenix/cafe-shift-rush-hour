extends Control
## Root router only. Each mode owns its view; the store survives either route.
const CounterTheme = preload("res://scripts/counter_theme.gd")
var current: Control
var return_button: Button

func _ready() -> void:
    get_window().size_changed.connect(_viewport_layout)
    KitchenSync.changed.connect(_sync_state)
    _viewport_layout()
    _show_counter()

func _viewport_layout() -> void:
    var actual: Vector2i = DisplayServer.window_get_size()
    var target: Vector2i = Vector2i(430, roundi(430.0 * actual.y / maxf(1, actual.x))) if actual.x < 700 else Vector2i.ZERO
    if get_window().content_scale_size != target:
        get_window().content_scale_size = target

func _replace(view: Control) -> void:
    if is_instance_valid(current):
        current.process_mode = Node.PROCESS_MODE_DISABLED
        remove_child(current)
        current.queue_free()
    current = view
    add_child(view)
    view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _show_counter() -> void:
    if KitchenSync.active:
        return
    _viewport_layout()
    var counter: Control = preload("res://scripts/counter_screen.gd").new()
    counter.desk_requested.connect(_show_desk)
    _replace(counter)

func _show_desk() -> void:
    var desk: Control = preload("res://scenes/order_desk.tscn").instantiate()
    desk.manage_viewport_scaling = false
    _replace(desk)
    return_button = CounterTheme.button("Cafe", _show_counter, "BackToCafe")
    return_button.add_theme_font_size_override("font_size", 12)
    desk._tabs.add_child(return_button)
    desk._tabs.move_child(return_button, 0)
    _sync_state()

func _sync_state() -> void:
    if is_instance_valid(return_button):
        return_button.disabled = KitchenSync.active
        return_button.tooltip_text = "Disconnect the online room before returning to the solo café." if KitchenSync.active else "Return to the hands-on café."
    if is_instance_valid(current) and current.get_script() == preload("res://scripts/order_desk.gd"):
        OrderStore.set_process(not KitchenSync.active)
