extends Control
## A small timing choice for each kitchen ticket: serve now, or wait for a better pour.

const TRACK := Color("66534d")
const SAFE := Color("639788")
const PERFECT := Color("e7ba72")
const NEEDLE := Color("fff5df")

var elapsed: float = 0.0
var reduced_motion: bool = false

func _ready() -> void:
    custom_minimum_size = Vector2(180, 22)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(not reduced_motion)

func _process(delta: float) -> void:
    elapsed += delta * (0.35 if reduced_motion else 1.0)
    queue_redraw()

func marker_position() -> float:
    return 0.5 + 0.5 * sin(elapsed * 2.0)

func quality_bonus() -> int:
    var distance: float = absf(marker_position() - 0.5)
    if distance <= 0.045:
        return 20
    if distance <= 0.20:
        return 10
    return 0

func quality_hint() -> String:
    match quality_bonus():
        20:
            return "PERFECT POUR  +20 XP"
        10:
            return "GOOD POUR  +10 XP"
        _:
            return "Wait for the gold needle in the green zone"

func _draw() -> void:
    var y: float = 4.0
    var track_height: float = maxf(10.0, size.y - 8.0)
    draw_rect(Rect2(0, y, size.x, track_height), TRACK)
    draw_rect(Rect2(size.x * 0.30, y, size.x * 0.40, track_height), SAFE)
    draw_rect(Rect2(size.x * 0.46, y, size.x * 0.08, track_height), PERFECT)
    var needle_x: float = clampf(marker_position() * size.x, 2.0, size.x - 2.0)
    draw_rect(Rect2(needle_x - 2.0, y - 2.0, 4.0, track_height + 4.0), NEEDLE)
    draw_rect(Rect2(0, y, size.x, track_height), Color(0, 0, 0, 0), false, 1.0)
