extends Control
## A small drawn star for the shift report. Drawn as a shape so it never
## depends on font glyph coverage (the default UI font has no ★).

var filled: bool = true

func _init() -> void:
    custom_minimum_size = Vector2(26, 26)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_filled(value: bool) -> void:
    if filled == value:
        return
    filled = value
    queue_redraw()

func _draw() -> void:
    var center: Vector2 = size / 2.0
    var outer: float = minf(size.x, size.y) * 0.44
    var inner: float = outer * 0.45
    var points := PackedVector2Array()
    for i in range(10):
        var radius: float = outer if i % 2 == 0 else inner
        var angle: float = -PI / 2.0 + i * PI / 5.0
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    var body: Color = Color("e7ba72") if filled else Color(1, 1, 1, 0.05)
    draw_colored_polygon(points, body)
    var outline: Color = Color("493a39") if filled else Color("6c5149")
    for i in range(points.size()):
        draw_line(points[i], points[(i + 1) % points.size()], outline, 1.5, true)
