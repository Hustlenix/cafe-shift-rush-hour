extends RefCounted
const PAPER := Color("fff0c9")
const INK := Color("3b2931")
const GOLD := Color("f0be6f")
const GREEN := Color("5b917e")
const CORAL := Color("c96c58")

static func panel(color: Color = PAPER) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = Color("593c3b")
    box.set_border_width_all(3)
    box.set_corner_radius_all(3)
    box.content_margin_left = 12
    box.content_margin_right = 12
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    return box

static func label(text: String, font_size: int = 18, color: Color = PAPER) -> Label:
    var value := Label.new()
    value.text = text
    value.add_theme_color_override("font_color", color)
    value.add_theme_font_size_override("font_size", font_size)
    value.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return value

static func button(text: String, action: Callable, id: String = "") -> Button:
    var value := Button.new()
    value.name = id if not id.is_empty() else text.validate_node_name()
    value.text = text
    value.custom_minimum_size = Vector2(54, 54)
    value.add_theme_font_size_override("font_size", 16)
    value.add_theme_color_override("font_color", INK)
    value.add_theme_color_override("font_hover_color", INK)
    value.add_theme_color_override("font_pressed_color", INK)
    value.add_theme_color_override("font_focus_color", INK)
    value.add_theme_color_override("font_hover_pressed_color", INK)
    value.add_theme_color_override("font_disabled_color", Color("887c70"))
    value.add_theme_stylebox_override("normal", panel())
    value.add_theme_stylebox_override("hover", panel(GOLD))
    value.add_theme_stylebox_override("pressed", panel(GREEN))
    value.add_theme_stylebox_override("disabled", panel(Color("c9bdab")))
    var focus := panel(Color(0, 0, 0, 0))
    focus.border_color = CORAL
    value.add_theme_stylebox_override("focus", focus)
    value.pressed.connect(action)
    return value
