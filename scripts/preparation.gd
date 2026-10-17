extends RefCounted
## One physical item. This model owns steps, skill input, and bounded quality.
signal checkpoint
signal completed
signal activity_started
const Recipes = preload("res://scripts/recipes.gd")
var product: String = ""
var index: int = 0
var progress: float = 0.0
var count: int = 0
var running: bool = false
var holding: bool = false
var quality: int = 0
var feedback: String = ""
var _last_direction: int = 0
var _finished: bool = false
var _has_started: bool = false

func begin(id: String, saved: Dictionary = {}) -> void:
    product = id if Recipes.DATA.has(id) else ""
    index = clampi(int(saved.get("step", 0)), 0, maxi(0, Recipes.steps(product).size() - 1))
    quality = clampi(int(saved.get("quality", 0)), 0, 20)
    _reset_step()
    _finished = false
    _has_started = false

func step() -> Array:
    var data: Array = Recipes.steps(product)
    return data[index] if not product.is_empty() and index < data.size() else []

func kind() -> String:
    return str(step()[0]) if not step().is_empty() else ""

func snapshot() -> Dictionary:
    # Interrupted gestures restart only the current step. Completed steps survive.
    return {"product": product, "step": index, "quality": quality}

func tick(delta: float) -> void:
    if _finished or delta <= 0.0:
        return
    if kind() == "hold" and holding:
        progress += minf(delta, 0.1) / 2.1
        if progress > 1.15:
            _retry("Spilled! Hold again and release at the line.")
    elif kind() == "heat" and running:
        progress += minf(delta, 0.1) / 3.6
        if progress > 1.12:
            _retry("Too dark! A fresh batch is ready; try again.")

func press() -> void:
    if _finished:
        return
    _mark_started()
    match kind():
        "pick": _next(2)
        "stack":
            count += 1
            if count >= int(step()[3]):
                _next(3)
        "hold":
            holding = true
            feedback = "Release at the marked line"
        "heat":
            if not running:
                running = true
                feedback = "Warming... lift when the label reads GOLDEN"
            elif progress >= 0.65 and progress <= 1.05:
                _next(5 if progress >= 0.75 and progress <= 0.92 else 2)
            else:
                _retry("Still pale. Let the next batch turn golden.")

func release() -> void:
    if kind() != "hold" or not holding or _finished:
        return
    holding = false
    if progress >= 0.65 and progress <= 1.05:
        _next(5 if progress >= 0.75 and progress <= 0.92 else 2)
    else:
        _retry("A little short. Hold again to the marked line.")

func stir(direction: int) -> void:
    if kind() != "stir" or _finished or direction == 0:
        return
    _mark_started()
    if direction != _last_direction:
        _last_direction = direction
        count += 1
        progress = float(count) / 8.0
        if count >= 8:
            _next(5)

func cut(start: Vector2, end: Vector2) -> void:
    if kind() == "cut" and not _finished:
        _mark_started()
        if absf(start.x - 0.5) <= 0.18 and absf(end.x - 0.5) <= 0.18 and start.y < 0.32 and end.y > 0.75:
            _next(4)
        else:
            feedback = "Follow the dashed seam, from top to bottom."

func plate(on_plate: bool) -> void:
    if kind() == "plate" and not _finished:
        _mark_started()
        if on_plate:
            _next(2)
        else:
            feedback = "Aim for the plate; the food stays on the board."

func _mark_started() -> void:
    if not _has_started:
        _has_started = true
        activity_started.emit()

func _retry(message: String) -> void:
    _reset_step()
    feedback = message

func _reset_step() -> void:
    progress = 0.0
    count = 0
    running = false
    holding = false
    _last_direction = 0
    feedback = ""

func _next(bonus: int) -> void:
    quality = mini(20, quality + bonus)
    index += 1
    _reset_step()
    if index >= Recipes.steps(product).size():
        _finished = true
        completed.emit()
    else:
        checkpoint.emit()
