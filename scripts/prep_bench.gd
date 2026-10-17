extends Control
## Equipment presentation and pointer/keyboard translation, with no scoring rules.
const CounterTheme = preload("res://scripts/counter_theme.gd")
const Recipes = preload("res://scripts/recipes.gd")
var model: RefCounted
var tray_order: Dictionary = {}
var product_name: String = ""
var heading: Label
var instruction: Label
var keys: Label
var pointer: Vector2
var dragging: bool = false
var drag_source: int = -1
var drag_start: Vector2
var last_stroke: Vector2
var _key_direction: int = 1
var _pressed_step: int = -1
var _art: Rect2
var primary_rect: Rect2
var food_rect: Rect2
var plate_rect: Rect2
var sources: Array[Rect2] = []

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    heading = CounterTheme.label("THE PREPARATION COUNTER", 20, CounterTheme.INK)
    instruction = CounterTheme.label("Tap a guest in the café to hear their order.", 16, CounterTheme.INK)
    instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    keys = CounterTheme.label("", 13, CounterTheme.INK)
    keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(heading)
    add_child(instruction)
    add_child(keys)
    resized.connect(_layout)
    _layout()

func bind(value: RefCounted, label: String = "") -> void:
    model = value
    product_name = label
    dragging = false
    drag_source = -1
    if model != null:
        grab_focus()
    queue_redraw()

func _layout() -> void:
    if heading == null:
        return
    var compact: bool = size.y < 310
    heading.position = Vector2(18, 8 if compact else 12)
    heading.size = Vector2(size.x - 36, 28)
    instruction.position = Vector2(18, 34 if compact else 43)
    instruction.size = Vector2(size.x - 36, 39 if compact else 50)
    instruction.add_theme_font_size_override("font_size", 13 if compact else 16)
    keys.position = Vector2(18, size.y - (34 if compact else 46))
    keys.size = Vector2(size.x - 36, 32 if compact else 42)
    keys.add_theme_font_size_override("font_size", 11 if compact else 13)
    _art = Rect2(18, 77 if compact else 99, size.x - 36, maxf(40, size.y - (117 if compact else 155)))
    primary_rect = Rect2(_art.position + _art.size * Vector2(0.12, 0.06), _art.size * Vector2(0.76, 0.86))
    food_rect = Rect2(_art.position + _art.size * Vector2(0.09, 0.19), _art.size * Vector2(0.34, 0.64))
    plate_rect = Rect2(_art.position + _art.size * Vector2(0.58, 0.19), _art.size * Vector2(0.34, 0.64))
    sources.clear()
    for i in range(3):
        sources.append(Rect2(_art.position + Vector2(_art.size.x * (0.035 + i * 0.33), 2), Vector2(_art.size.x * 0.27, maxf(56, _art.size.y * 0.36))))

func _process(delta: float) -> void:
    if model != null:
        model.tick(delta)
        if not model.step().is_empty():
            heading.text = "%s  ·  %d/%d" % [product_name, mini(model.index + 1, Recipes.steps(model.product).size()), Recipes.steps(model.product).size()]
            heading.add_theme_font_size_override("font_size", 16 if size.x < 450 else 21)
            instruction.text = model.feedback if not model.feedback.is_empty() else str(model.step()[1])
            keys.text = {"pick":"Drag ingredient > equipment · Space: place", "stack":"Drag the highlighted ingredient > centre · Space: next", "hold":"Hold the tap; release in the marked band · hold Space", "heat":"Tap equipment to start / lift · Space: start / lift", "stir":"Drag left and right across the bowl · alternate Left / Right", "cut":"Draw down the dotted seam · Enter: guided slice", "plate":"Drag food > plate · Enter: plate"}.get(model.kind(), "")
    else:
        heading.text = "READY TO DELIVER" if not tray_order.is_empty() else "YOUR PREPARATION COUNTER"
        heading.add_theme_font_size_override("font_size", 17 if size.x < 450 or size.y < 310 else 21)
        instruction.text = "Pick up the finished tray below, then tap your guest." if not tray_order.is_empty() else "Tap a guest, then choose an item from their order."
        keys.text = "G: cycle guests · Tab: select an item or tray · Enter: activate"
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if model == null or model.step().is_empty():
        return
    if event is InputEventKey:
        if event.echo:
            return
        if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
            if event.pressed:
                match model.kind():
                    "cut": model.cut(Vector2(0.5, 0.1), Vector2(0.5, 0.9))
                    "plate": model.plate(true)
                    "stir":
                        _key_direction *= -1
                        model.stir(_key_direction)
                    _: model.press()
            elif event.keycode == KEY_SPACE:
                model.release()
            accept_event()
        elif event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
            model.stir(-1 if event.keycode == KEY_LEFT else 1)
            accept_event()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _pointer_button(event.position, event.pressed)
        accept_event()
    elif event is InputEventScreenTouch:
        _pointer_button(event.position, event.pressed)
        accept_event()
    elif event is InputEventMouseMotion or event is InputEventScreenDrag:
        pointer = event.position
        if dragging and model.index != _pressed_step:
            dragging = false
        if dragging and model.kind() == "stir" and absf(pointer.x - last_stroke.x) >= 18:
            model.stir(1 if pointer.x > last_stroke.x else -1)
            last_stroke = pointer
        accept_event()

func _pointer_button(at: Vector2, pressed: bool) -> void:
    pointer = at
    if pressed:
        grab_focus()
        _pressed_step = model.index
        drag_start = at
        last_stroke = at
        drag_source = -1
        if model.kind() in ["hold", "heat"] and primary_rect.has_point(at):
            model.press()
        elif model.kind() == "stack":
            for i in range(sources.size()):
                if sources[i].has_point(at):
                    drag_source = i
            dragging = drag_source == model.count
            if not dragging:
                model.feedback = "Use the highlighted ingredient first."
        else:
            dragging = primary_rect.has_point(at) if model.kind() in ["cut", "stir"] else food_rect.has_point(at)
    else:
        if model.index != _pressed_step:
            dragging = false
            return
        var before: String = model.kind()
        if before == "hold":
            model.release()
        elif dragging:
            match before:
                "pick":
                    if plate_rect.has_point(at): model.press()
                    else: model.feedback = "Drop it into the equipment on the right."
                "stack":
                    if at.y > _art.position.y + _art.size.y * 0.42 and primary_rect.has_point(at): model.press()
                    else: model.feedback = "Drop the ingredient into the centre."
                "cut": model.cut((drag_start - primary_rect.position) / primary_rect.size, (at - primary_rect.position) / primary_rect.size)
                "plate": model.plate(plate_rect.has_point(at))
        dragging = false
        drag_source = -1

func _draw() -> void:
    draw_style_box(CounterTheme.panel(Color("dfb783")), Rect2(Vector2.ZERO, size))
    if heading == null:
        return
    for y in range(int(_art.position.y), int(_art.end.y), 24):
        draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color("c99d70"), 2)
    if model == null or model.step().is_empty():
        _finished_tray()
        return
    var kind: String = model.kind()
    match kind:
        "hold": _brewer()
        "heat": _heater()
        "stir": _bowl()
        "cut": _board()
        "stack": _ingredients()
        "pick", "plate":
            _plate(plate_rect)
            if kind == "pick":
                draw_style_box(CounterTheme.panel(Color("8ca38b")), food_rect)
                _text(str(model.step()[2]), food_rect.position + Vector2(0, 24), 13, food_rect.size.x)
                _text("DROP HERE", plate_rect.position + Vector2(0, 28), 12, plate_rect.size.x)
            if kind == "pick": _ingredient(food_rect.grow(-12))
            else: _food(food_rect.grow(-10), Color.WHITE)
    if dragging and kind in ["pick", "plate", "stack"]:
        if kind == "pick":
            _ingredient(Rect2(pointer - Vector2(24, 24), Vector2(48, 48)))
        elif kind == "stack":
            draw_style_box(CounterTheme.panel(CounterTheme.GOLD), Rect2(pointer - Vector2(23, 17), Vector2(46, 34)))
        else:
            var texture: Texture2D = Recipes.texture(model.product)
            draw_texture_rect(texture, Rect2(pointer - Vector2(28, 28), Vector2(56, 56)), false, Color(1, 1, 1, 0.85))
    if has_focus():
        draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), Color("fff4cf"), false, 2)

func _text(text: String, at: Vector2, font_size: int = 16, width: float = -1, color: Color = CounterTheme.INK) -> void:
    draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)

func _plate(rect: Rect2) -> void:
    draw_style_box(CounterTheme.panel(Color("eee6cf")), rect)
    draw_rect(rect.grow(-9), Color("d1c8ac"), false, 3)

func _finished_tray() -> void:
    var food: Array[String] = []
    for item in tray_order.get("items", []):
        for _i in range(int(tray_order.get("crafted", {}).get(str(item["id"]), 0))):
            food.append(str(item["id"]))
    var height: float = minf(_art.size.y - 12, 170)
    var width: float = minf(_art.size.x - 20, maxf(130, food.size() * height))
    var surface := Rect2(_art.get_center() - Vector2(width, height) / 2, Vector2(width, height))
    draw_style_box(CounterTheme.panel(Color("9b6d4e")), surface)
    if food.is_empty():
        _plate(surface.grow(-12))
    else:
        var cell: float = minf(height - 12, width / food.size())
        for i in range(food.size()):
            var rect := Rect2(surface.position + Vector2(i * width / food.size() + 6, 6), Vector2(cell - 12, height - 12))
            _plate(rect)
            var extent: float = minf(rect.size.x, rect.size.y) - 12
            draw_texture_rect(Recipes.texture(food[i]), Rect2(rect.get_center() - Vector2.ONE * extent / 2, Vector2.ONE * extent), false)

func _food(rect: Rect2, tint: Color) -> void:
    var extent: float = minf(rect.size.x, rect.size.y)
    draw_texture_rect(Recipes.texture(model.product), Rect2(rect.get_center() - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false, tint)

func _ingredient(rect: Rect2) -> void:
    var label: String = str(model.step()[2])
    var centre: Vector2 = rect.get_center()
    var half: float = minf(rect.size.x, rect.size.y) * 0.34
    var color := Color("9cb270") if label == "MATCHA" else (Color("e7a34b") if label == "HONEY" else Color("70503e"))
    draw_rect(Rect2(centre - Vector2(half, half), Vector2(half * 2, half * 2)), color)
    draw_rect(Rect2(centre - Vector2(half + 4, half + 5), Vector2(half * 2 + 8, 9)), Color("e9d8ad"))
    for i in range(3):
        draw_line(centre + Vector2(-half * 0.5 + i * half * 0.5, -half * 0.35), centre + Vector2(-half * 0.5 + i * half * 0.5, half * 0.45), Color("f6dea4"), 3)
    if label == "COOKIE JAR":
        draw_texture_rect(Recipes.texture("cookie"), Rect2(centre - Vector2.ONE * half, Vector2.ONE * half * 2), false)

func _brewer() -> void:
    var r: Rect2 = primary_rect
    draw_style_box(CounterTheme.panel(Color("66857e")), r)
    draw_rect(Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 24, r.size.y * 0.28)), Color("334b4a"))
    _text(str(model.step()[2]), r.position + Vector2(0, 35), 18, r.size.x, CounterTheme.PAPER)
    var cup := Rect2(r.position + r.size * Vector2(0.37, 0.42), r.size * Vector2(0.26, 0.46))
    draw_rect(cup, Color("f6e6c6"))
    var fill: float = clampf(model.progress, 0, 1)
    draw_rect(Rect2(cup.position + Vector2(5, cup.size.y * (1.0 - fill)), Vector2(cup.size.x - 10, cup.size.y * fill - 1)), Color("8b5a41"))
    draw_rect(Rect2(cup.position + Vector2(0, cup.size.y * 0.08), Vector2(cup.size.x, cup.size.y * 0.17)), Color(0.94, 0.74, 0.44, 0.6))
    draw_line(cup.position + Vector2(-8, cup.size.y * 0.17), cup.position + Vector2(cup.size.x + 8, cup.size.y * 0.17), CounterTheme.INK, 3)
    if model.holding:
        draw_rect(Rect2(r.position + r.size * Vector2(0.48, 0.29), Vector2(r.size.x * 0.04, r.size.y * 0.4)), Color("c69a66"))
    _text("HOLD / RELEASE", r.position + Vector2(0, r.size.y - 7), 13, r.size.x)

func _heater() -> void:
    var r: Rect2 = primary_rect
    draw_style_box(CounterTheme.panel(Color("ae6550")), r)
    var glass := Rect2(r.position + Vector2(12, 36), r.size - Vector2(24, 75))
    draw_rect(glass, Color("463632"))
    _food(glass.grow(-8), Color(1.0, 1.0 - model.progress * 0.25, 1.0 - model.progress * 0.5))
    var state: String = "TAP TO START" if not model.running else ("GOLDEN · LIFT!" if model.progress >= 0.65 and model.progress <= 1.05 else "WARMING...")
    _text(str(model.step()[2]) + "  ·  " + state, r.position + Vector2(0, 25), 15, r.size.x)
    var bar := Rect2(r.position + Vector2(14, r.size.y - 28), Vector2(r.size.x - 28, 14))
    draw_rect(bar, Color("eddbb4"))
    draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.58, 0), Vector2(bar.size.x * 0.35, bar.size.y)), CounterTheme.GOLD)
    draw_line(bar.position + Vector2(bar.size.x * minf(model.progress / 1.12, 1.0), -4), bar.position + Vector2(bar.size.x * minf(model.progress / 1.12, 1.0), 18), CounterTheme.INK, 4)

func _bowl() -> void:
    var centre: Vector2 = primary_rect.get_center()
    var radius: float = minf(primary_rect.size.x, primary_rect.size.y) * 0.42
    draw_circle(centre + Vector2(0, 5), radius + 8, Color("6c6558"))
    draw_circle(centre, radius, Color("f3e3bb"))
    draw_circle(centre, radius * 0.78, Color("87a669") if model.product == "matcha" else Color("f2d7a1"))
    var whisk: Vector2 = pointer if dragging else centre + Vector2(radius * 0.5, -radius * 0.4)
    whisk = whisk.clamp(centre - Vector2.ONE * radius, centre + Vector2.ONE * radius)
    draw_line(whisk, whisk + Vector2(22, -42), Color("62483a"), 7)
    draw_arc(whisk, 17, 0, TAU, 16, Color("eee9cb"), 3)
    _text("%d / 8 STROKES" % model.count, Vector2(_art.position.x, _art.end.y - 2), 16, _art.size.x)

func _board() -> void:
    draw_style_box(CounterTheme.panel(Color("b98556")), primary_rect)
    _food(primary_rect.grow(-10), Color.WHITE)
    var x: float = primary_rect.get_center().x
    for y in range(int(primary_rect.position.y), int(primary_rect.end.y), 18):
        draw_line(Vector2(x, y), Vector2(x, y + 9), Color("fff6d7"), 4)
    _text("SLICE DOWN", primary_rect.position + Vector2(0, 22), 14, primary_rect.size.x)
    if dragging:
        draw_line(drag_start, pointer, Color("e9e1ce"), 5)

func _ingredients() -> void:
    var names: Array = ["ICE 1", "ICE 2", "ICE 3"]
    if model.product == "chai": names = ["GINGER", "CARDAMOM", "TEA"]
    elif model.product == "toastie": names = ["BREAD", "CHEESE", "BREAD"]
    for i in range(3):
        var r: Rect2 = sources[i]
        var tint: Color = CounterTheme.GOLD if i == model.count else Color("b5a58c")
        draw_style_box(CounterTheme.panel(tint), r)
        _text(names[i], r.position + Vector2(0, r.size.y * 0.55), 13, r.size.x)
        if i < model.count:
            _text("OK", r.position + Vector2(0, r.size.y - 5), 15, r.size.x)
    var target := Rect2(_art.position + _art.size * Vector2(0.27, 0.49), _art.size * Vector2(0.46, 0.46))
    _plate(target)
    for i in range(model.count):
        draw_rect(Rect2(target.position + Vector2(16, target.size.y - 17 - i * 13), Vector2(target.size.x - 32, 11)), Color("e7ce8b") if i != 1 else Color("efa64b"))
    _text("DROP HERE", target.position + Vector2(0, 19), 13, target.size.x)
