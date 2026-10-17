extends Control
## A responsive title screen using the same room, characters and palette as play.
signal action_requested(action: String)
var host: Control
var room: Control
var row: BoxContainer
var panel: PanelContainer
var title: Label
var copy: Label
var resume: Button
var lesson: Button
var rush: Button
var practice: Button

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color("211b22")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
    add_child(margin)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    margin.add_child(scroll)
    row = BoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation",20)
    scroll.add_child(row)
    room = preload("res://scripts/cafe_view.gd").new()
    room.mouse_filter = Control.MOUSE_FILTER_IGNORE
    room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    room.size_flags_vertical = Control.SIZE_EXPAND_FILL
    row.add_child(room)
    room.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel = host._panel(Color("fff3d2"))
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(panel)
    var box: VBoxContainer = host._column(10)
    panel.add_child(box)
    title = host._label("CAFÉ SHIFT",40)
    box.add_child(title)
    box.add_child(host._label("R U S H   H O U R",16,Color("a04d3e")))
    copy = host._label("One café. Too many orders.\nFind your rhythm before the rush.",18)
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.custom_minimum_size.y = 62
    box.add_child(copy)
    lesson = _action(box,"First time? Learn in 45 seconds","LearnCounter","TUTORIAL",false)
    rush = _action(box,"Start Rush Hour","StartRush","RUSH",true)
    practice = _action(box,"Practice Without Timer","StartPractice","FREE",false)
    _action(box,"Two-Device Kitchen","TwoDeviceKitchen","ONLINE",false)
    _action(box,"Settings","WelcomeSettings","SETTINGS",false)
    resume = _action(box,"Continue saved shift","ResumeShift","RESUME",false)
    var note: Label = host._label("Five happy tables · three minutes\nThe clock starts only when you choose Rush Hour.",14,Color("75594b"))
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(note)
    resized.connect(_layout)
    _layout()

func _action(box: VBoxContainer, text: String, id: String, action: String, primary: bool) -> Button:
    var button: Button = host._button(text,func(): action_requested.emit(action),primary,id)
    button.custom_minimum_size.y = 50
    button.add_theme_font_size_override("font_size",17)
    box.add_child(button)
    return button

func _layout() -> void:
    var portrait: bool = size.x < 700
    row.vertical = portrait
    room.custom_minimum_size = Vector2(0,200) if portrait else Vector2(400,380)
    panel.custom_minimum_size.x = 0 if portrait else 400
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
    title.add_theme_font_size_override("font_size",34 if portrait else 40)

func show_welcome(success: bool = false) -> void:
    title.text = "FIRST ORDER COMPLETE!" if success else "CAFÉ SHIFT"
    title.add_theme_font_size_override("font_size",24 if success else (34 if size.x < 700 else 40))
    copy.text = "Lovely service! You matched a recipe, sent its ticket and served your first guest. Ready for the rush?" if success else "One café. Too many orders.\nFind your rhythm before the rush."
    rush.text = "Start My Shift" if success else "Start Rush Hour"
    practice.text = "Keep Practicing" if success else "Practice Without Timer"
    lesson.text = "Replay the tutorial" if OrderStore.tutorial_completed else "First time? Learn in 45 seconds"
    resume.visible = KitchenSync.active or not OrderStore.orders.is_empty() or not OrderStore.cart.is_empty() or (OrderStore.shift.mode == "RUSH" and OrderStore.shift.elapsed > 0)
    resume.text = "Return to online kitchen" if KitchenSync.active else "Continue saved shift"
    room.reduced_motion = host.motion_off
    show()
    if success or OrderStore.tutorial_completed: rush.grab_focus()
    else: lesson.grab_focus()
