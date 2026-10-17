extends Control
## Mode selection, pause, settings and end-of-shift report live outside gameplay.
signal resumed
signal mode_requested(mode: String)
signal desk_requested
signal settings_changed(sound: bool, motion: bool)
const CounterTheme = preload("res://scripts/counter_theme.gd")
var title: Label
var detail: Label
var resume: Button
var sound: CheckButton
var motion: CheckButton
var _confirm: Control
var _pending: String = ""
var persistence_enabled: bool = true

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color(0.1, 0.07, 0.09, 0.95)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", CounterTheme.panel())
    centre.add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    resized.connect(func(): scroll.custom_minimum_size = Vector2(330, minf(520, size.y - 48)))
    scroll.custom_minimum_size = Vector2(330, minf(520, size.y - 48))
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(330, 0)
    box.add_theme_constant_override("separation", 8)
    scroll.add_child(box)
    title = CounterTheme.label("CAFÉ SHIFT", 30, CounterTheme.INK)
    box.add_child(title)
    detail = CounterTheme.label("A little café. A counter of your own.\nPrepare the food. Hand over a happy tray.", 16, CounterTheme.INK)
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.custom_minimum_size = Vector2(320, 64)
    box.add_child(detail)
    resume = CounterTheme.button("Continue at counter", func(): resumed.emit(), "ResumeCounter")
    box.add_child(resume)
    box.add_child(CounterTheme.button("New practice · no deadline", func(): _request("FREE"), "Practice"))
    box.add_child(CounterTheme.button("Rush hour · 5 guests in 3 minutes", func(): _request("RUSH"), "Rush"))
    box.add_child(CounterTheme.button("Order desk / connect a kitchen", func(): desk_requested.emit(), "OpenDesk"))
    sound = CheckButton.new()
    sound.name = "CounterSound"
    sound.text = "Sound & café ambience"
    sound.button_pressed = true
    motion = CheckButton.new()
    motion.name = "CounterMotion"
    motion.text = "Reduce motion"
    for toggle in [sound, motion]:
        toggle.custom_minimum_size.y = 54
        toggle.add_theme_color_override("font_color", CounterTheme.INK)
        toggle.add_theme_color_override("font_pressed_color", CounterTheme.INK)
        toggle.add_theme_color_override("font_hover_color", CounterTheme.INK)
        toggle.add_theme_color_override("font_focus_color", CounterTheme.INK)
        toggle.add_theme_color_override("font_hover_pressed_color", CounterTheme.INK)
        box.add_child(toggle)
        toggle.toggled.connect(func(_value: bool):
            _save_settings()
            settings_changed.emit(sound.button_pressed, motion.button_pressed)
        )
    var config := ConfigFile.new()
    if persistence_enabled and config.load("user://counter_settings.cfg") == OK:
        sound.set_pressed_no_signal(bool(config.get_value("play", "sound", true)))
        motion.set_pressed_no_signal(bool(config.get_value("play", "motion", false)))
    _confirm = Control.new()
    _confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_confirm)
    var cover := ColorRect.new()
    cover.color = Color(0.1, 0.07, 0.09, 0.9)
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _confirm.add_child(cover)
    var confirm_centre := CenterContainer.new()
    confirm_centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _confirm.add_child(confirm_centre)
    var confirm_panel := PanelContainer.new()
    confirm_panel.add_theme_stylebox_override("panel", CounterTheme.panel())
    confirm_centre.add_child(confirm_panel)
    var confirm_box := VBoxContainer.new()
    confirm_box.custom_minimum_size.x = 310
    confirm_box.add_theme_constant_override("separation", 12)
    confirm_panel.add_child(confirm_box)
    confirm_box.add_child(CounterTheme.label("Start a fresh shift?", 23, CounterTheme.INK))
    var warning := CounterTheme.label("This replaces the current shift and unfinished trays. Lifetime XP stays.", 16, CounterTheme.INK)
    warning.custom_minimum_size = Vector2(310, 66)
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    confirm_box.add_child(warning)
    confirm_box.add_child(CounterTheme.button("Keep current shift", func():
        _confirm.hide()
        resume.grab_focus()
    , "CounterCancelReset"))
    confirm_box.add_child(CounterTheme.button("Start new shift", func():
        _confirm.hide()
        mode_requested.emit(_pending)
    , "CounterConfirmReset"))
    _confirm.hide()

func _request(mode: String) -> void:
    _pending = mode
    if not OrderStore.orders.is_empty() or OrderStore.shift.served > 0:
        _confirm.show()
        _confirm.find_child("CounterCancelReset", true, false).grab_focus()
    else:
        mode_requested.emit(mode)

func _save_settings() -> void:
    if not persistence_enabled: return
    var config := ConfigFile.new()
    config.set_value("play", "sound", sound.button_pressed)
    config.set_value("play", "motion", motion.button_pressed)
    config.save("user://counter_settings.cfg")

func show_menu(report: bool = false) -> void:
    _confirm.hide()
    title.text = "FIVE HAPPY TABLES!" if report and OrderStore.shift.result == "SUCCESS" else ("THE SHIFT IS OVER" if report else "CAFÉ SHIFT")
    title.add_theme_font_size_override("font_size", 24 if report else 30)
    detail.text = ("%d / 5 served · Rs %d earned\n%d XP · best streak %d · %d missed" % [OrderStore.shift.served, OrderStore.earnings, OrderStore.shift.score, OrderStore.shift.best_streak, OrderStore.shift.missed]) if report else "Tap a guest > craft their order > pick up the tray > tap the guest to deliver.\nPractice first; Rush starts only when you choose it."
    resume.disabled = report
    visible = true
    resume.grab_focus()
