extends Control
## An animated, live view of the customers in the authoritative shift model.

signal customer_selected(request_id: String)

## Sprite sheets hold 24 frames: 6 each for right, up, left, down (front), in that order.
const DIR_ROWS: Dictionary = {"right": 0, "up": 6, "left": 12, "down": 18}
const SPAWN_POINT: Vector2 = Vector2(250, 134)
const EXIT_POINT: Vector2 = Vector2(272, 134)
const EXIT_ERASE_X: float = 258.0
const QUEUE_SLOTS: Array[Vector2] = [
    Vector2(98, 124), Vector2(128, 127), Vector2(158, 130), Vector2(192, 129), Vector2(210, 130)
]

var room: Texture2D
var sprites: Dictionary = {}
var run_sprites: Dictionary = {}
var actors: Dictionary = {}
var clock: float = 0.0
var reduced_motion: bool = false
var selected_request_id: String = ""
var celebrations: Dictionary = {}
var floats: Array[Dictionary] = []
var confetti_pieces: Array[Dictionary] = []

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_PASS
    if ResourceLoader.exists("res://assets/licensed/cafe.png"):
        room = load("res://assets/licensed/cafe.png")
    for name in ["Amelia", "Adam", "Alex", "Bob", "Lucy", "Ash"]:
        var path: String = "res://assets/licensed/%s_idle_anim.png" % name
        if ResourceLoader.exists(path):
            sprites[name] = load(path)
        var run_path: String = "res://assets/licensed/%s_run.png" % name
        if ResourceLoader.exists(run_path):
            run_sprites[name] = load(run_path)

func _process(delta: float) -> void:
    clock += delta
    var ids: Array[String] = []
    var index: int = 0
    for request in OrderStore.shift.requests:
        var id: String = str(request["id"])
        ids.append(id)
        var goal: Vector2 = _queue_slot(index)
        if not actors.has(id):
            actors[id] = {"id": id, "pos": SPAWN_POINT, "name": str(request["name"]), "state": "WAITING", "patience": 65.0, "dialogue": _dialogue_for(request), "facing": "left", "moving": true}
            celebrations.erase(id)
        var before: Vector2 = actors[id]["pos"]
        var after: Vector2 = goal if reduced_motion else before.move_toward(goal, delta * 30)
        actors[id]["pos"] = after
        _update_facing(actors[id], after - before)
        actors[id]["state"] = str(request["state"])
        actors[id]["patience"] = float(request["patience"])
        actors[id]["max_patience"] = float(request.get("max_patience",65))
        actors[id]["personality"] = str(request.get("personality","Regular"))
        index += 1
    for id in actors.keys():
        if id not in ids:
            actors[id]["state"] = "LEAVING"
            var before: Vector2 = actors[id]["pos"]
            var after: Vector2 = EXIT_POINT if reduced_motion else before.move_toward(EXIT_POINT, delta * 65)
            actors[id]["pos"] = after
            _update_facing(actors[id], after - before)
            if after.x >= EXIT_ERASE_X:
                actors.erase(id)
    for id in celebrations.keys():
        celebrations[id] = float(celebrations[id]) - delta
        if float(celebrations[id]) <= 0.0:
            celebrations.erase(id)
    for i in range(floats.size() - 1, -1, -1):
        floats[i]["t"] = float(floats[i]["t"]) + delta
        if float(floats[i]["t"]) > 1.15:
            floats.remove_at(i)
    for i in range(confetti_pieces.size() - 1, -1, -1):
        var piece: Dictionary = confetti_pieces[i]
        piece["life"] = float(piece["life"]) - delta
        var vel: Vector2 = piece["vel"]
        vel.y += 14.0 * delta
        vel.x += sin(clock * 3.0 + float(piece["phase"])) * 6.0 * delta
        piece["vel"] = vel
        piece["pos"] = (piece["pos"] as Vector2) + vel * delta
        if float(piece["life"]) <= 0.0 or (piece["pos"] as Vector2).y > 205.0:
            confetti_pieces.remove_at(i)
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _actor_at(motion.position).is_empty() else Control.CURSOR_ARROW
        return
    var pressed: bool = false
    var point: Vector2 = Vector2.ZERO
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event
        pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
        point = mouse_event.position
    elif event is InputEventScreenTouch:
        var touch_event: InputEventScreenTouch = event
        pressed = touch_event.pressed
        point = touch_event.position
    if not pressed:
        return
    var hit: String = _actor_at(point)
    if not hit.is_empty():
        customer_selected.emit(hit)
        accept_event()

func _actor_at(point: Vector2) -> String:
    var scale_factor: float = minf(size.x / 256, size.y / 192)
    var origin: Vector2 = (size - Vector2(256, 192) * scale_factor) / 2
    for actor in actors.values():
        if str(actor.get("state", "")) != "WAITING":
            continue
        var actor_position: Vector2 = origin + (actor["pos"] as Vector2) * scale_factor
        var hit_box := Rect2(actor_position - Vector2(5, 8) * scale_factor, Vector2(26, 48) * scale_factor)
        if hit_box.has_point(point):
            return str(actor["id"])
    return ""

func _queue_slot(index: int) -> Vector2:
    return QUEUE_SLOTS[clampi(index, 0, QUEUE_SLOTS.size() - 1)]

func _update_facing(actor: Dictionary, moved: Vector2) -> void:
    if moved.length() <= 0.05:
        actor["moving"] = false
        if str(actor.get("state", "")) == "WAITING":
            actor["facing"] = "down"
        return
    actor["moving"] = true
    if absf(moved.x) >= absf(moved.y):
        actor["facing"] = "right" if moved.x > 0.0 else "left"
    else:
        actor["facing"] = "down" if moved.y > 0.0 else "up"

func _dialogue_for(request: Dictionary) -> String:
    var recipe: Dictionary = request.get("recipe", {})
    var short_names: Dictionary = {
        "espresso": "espresso", "latte": "latte", "coldbrew": "cold brew",
        "chai": "chai", "matcha": "matcha", "croissant": "croissant",
        "toastie": "toastie", "brownie": "brownie", "cookie": "cookie"
    }
    var lines: PackedStringArray = []
    for key in recipe:
        var label: String = str(short_names.get(str(key), str(key)))
        var quantity: int = int(recipe[key])
        if quantity > 1:
            lines.append(str(quantity) + " " + label + "s")
        else:
            lines.append(("an " if "aeiou".contains(label.substr(0, 1)) else "a ") + label)
    if lines.is_empty():
        return "Something warm and lovely."
    var text: String = " and ".join(lines)
    return text.substr(0, 1).to_upper() + text.substr(1) + ", please."

func _draw() -> void:
    var scale_factor: float = minf(size.x / 256, size.y / 192)
    var origin: Vector2 = (size - Vector2(256, 192) * scale_factor) / 2
    draw_style_box(_shadow(), Rect2(origin + Vector2(4, 7), Vector2(256, 192) * scale_factor))
    draw_set_transform(origin, 0, Vector2.ONE * scale_factor)
    if room:
        draw_texture(room, Vector2.ZERO)
    else:
        draw_rect(Rect2(0, 0, 256, 192), Color("f3d9b1"))
        draw_rect(Rect2(8, 50, 240, 134), Color("c89970"))
        draw_rect(Rect2(112, 70, 128, 32), Color("896352"))
        for pos in [Vector2(25,85), Vector2(60,140), Vector2(190,145)]:
            draw_rect(Rect2(pos, Vector2(32,20)), Color("eed4a8"))
    # The barista works behind the counter; warm steam moves over the brewer.
    _draw_actor("Lucy", Vector2(169, 51), "BARISTA")
    for actor in actors.values():
        _draw_actor(str(actor["name"]), actor["pos"], str(actor["state"]), str(actor.get("id", "")), float(actor.get("patience", 65.0)), str(actor.get("facing", "down")), bool(actor.get("moving", false)))
    for id in celebrations.keys():
        if actors.has(id):
            _draw_hearts(actors[id]["pos"] as Vector2, clampf(float(celebrations[id]) / 0.9, 0.0, 1.0))
    for piece in confetti_pieces:
        var confetti_color: Color = piece["color"]
        confetti_color.a *= clampf(float(piece["life"]) / 0.5, 0.0, 1.0)
        draw_rect(Rect2(piece["pos"], piece["size"]), confetti_color)
    for i in range(4):
        var t: float = 0.5 if reduced_motion else fmod(clock * 0.5 + i * 0.27, 1.0)
        var sway: float = 0.0 if reduced_motion else sin(clock * 1.3 + i * 1.9) * 1.2
        var wx: float = 138.0 + i * 2.4 + sway
        draw_line(Vector2(wx, 63 - t * 16), Vector2(wx + 1.6, 58.5 - t * 16), Color(1, 0.95, 0.82, (1 - t) * 0.8), 1)
    draw_set_transform(Vector2.ZERO)
    _draw_screen_overlays(scale_factor, origin)

func _draw_actor(name: String, pos: Vector2, state: String, request_id: String = "", patience: float = 65.0, facing: String = "down", moving: bool = false) -> void:
    draw_ellipse_shadow(pos + Vector2(8,28))
    if sprites.has(name):
        var sheet: Texture2D = sprites[name]
        if moving and run_sprites.has(name):
            sheet = run_sprites[name]
        var row: int = int(DIR_ROWS.get(facing, 18))
        var frame: int = 0 if reduced_motion else int(clock * (10.0 if moving else 5.0)) % 6
        draw_texture_rect_region(sheet, Rect2(pos, Vector2(16,32)), Rect2((row + frame)*16,0,16,32))
    else:
        draw_rect(Rect2(pos+Vector2(3,4),Vector2(10,12)),Color("daa875"))
        draw_rect(Rect2(pos+Vector2(2,17),Vector2(12,12)),Color("689d8f"))
    if state == "BARISTA":
        return
    var selected: bool = request_id == selected_request_id and not request_id.is_empty()
    if selected:
        draw_rect(Rect2(pos - Vector2(2,2), Vector2(20,36)), Color("e7ba72"), false, 1.0)
    if state == "KITCHEN":
        draw_rect(Rect2(pos+Vector2(5,-6),Vector2(7,5)),Color("639788"))
        draw_line(pos+Vector2(7,-7),pos+Vector2(7,-9),Color("639788"),1)
        draw_line(pos+Vector2(10,-7),pos+Vector2(10,-9),Color("639788"),1)
    elif state == "LEAVING":
        pass  # No icon clutter over a guest that is already walking out.
    elif patience <= 20.0:
        draw_rect(Rect2(pos+Vector2(7,-7),Vector2(2,5)),Color("b84f41"))
        draw_rect(Rect2(pos+Vector2(7,-1),Vector2(2,2)),Color("b84f41"))
    elif selected:
        draw_rect(Rect2(pos+Vector2(5,-6),Vector2(7,5)),Color("a84f41"))
        draw_rect(Rect2(pos+Vector2(6,-7),Vector2(5,1)),Color("a84f41"))
    else:
        for i in range(3):
            draw_rect(Rect2(pos+Vector2(4+i*4,-4),Vector2(2,2)),Color("b96858"))

func actor_dialogue(request_id: String) -> String:
    if request_id.is_empty() or not actors.has(request_id):
        return ""
    return str(actors[request_id].get("dialogue", ""))

func _draw_screen_overlays(scale_factor: float, origin: Vector2) -> void:
    ## Name tags and the selected guest's order bubble live in screen space so text stays crisp at any zoom.
    var font: Font = ThemeDB.fallback_font
    for actor in actors.values():
        var sprite: Vector2 = origin + (actor["pos"] as Vector2) * scale_factor
        var label: String = str(actor.get("name", ""))
        if label.is_empty():
            continue
        var name_size: int = int(clampf(round(scale_factor * 2.8), 10.0, 14.0))
        var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
        var baseline: Vector2 = Vector2(sprite.x + 8.0 * scale_factor - label_width * 0.5, sprite.y + 32.0 * scale_factor + name_size + 2.0)
        draw_string(font, baseline + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(0.16, 0.11, 0.12, 0.8))
        draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color("fff3d2"))
        if str(actor.get("state","")) != "LEAVING":
            var badge: String = {"Impatient":"!","Generous":"+","Big Order":"2x","VIP":"★"}.get(str(actor.get("personality","Regular")),"")
            if badge != "": draw_string(font,baseline+Vector2(label_width+3,0),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size,Color("e7ba72"))
            var ratio: float = clampf(float(actor["patience"])/maxf(1,float(actor.get("max_patience",65))),0,1)
            var at: Vector2 = baseline+Vector2(label_width*0.5-18,6)
            draw_rect(Rect2(at,Vector2(36,4)),Color("493a39"))
            draw_rect(Rect2(at,Vector2(36*ratio,4)),Color("c86652") if ratio < 0.25 else Color("6da18b"))
    if actors.is_empty():
        var hint: String = "The floor is quiet · welcome a guest"
        var hint_size: int = int(clampf(round(scale_factor * 2.2), 11.0, 14.0))
        var hint_width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
        var hint_pos: Vector2 = Vector2(origin.x + 128.0 * scale_factor - hint_width * 0.5, origin.y + 186.0 * scale_factor)
        draw_string(font, hint_pos + Vector2(1, 1), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.14, 0.1, 0.11, 0.6))
        draw_string(font, hint_pos, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(1.0, 0.95, 0.82, 0.85))
    for popup in floats:
        var float_pos: Vector2
        var float_id: String = str(popup.get("id", ""))
        if actors.has(float_id):
            float_pos = origin + ((actors[float_id]["pos"] as Vector2) + Vector2(8.0, -4.0)) * scale_factor
        else:
            float_pos = origin + Vector2(208.0, 96.0) * scale_factor
        var rise: float = 0.0 if reduced_motion else (float(popup["t"]) / 1.15) * 26.0 * scale_factor
        var fade: float = clampf(1.0 - float(popup["t"]) / 1.15, 0.0, 1.0)
        var pop_size: int = int(clampf(round(scale_factor * 2.4), 11.0, 15.0))
        var pop_color: Color = popup["color"]
        pop_color.a = fade
        var pop_shadow: Color = Color(0.16, 0.11, 0.12, 0.75 * fade)
        var line_y: float = float_pos.y - rise
        for line in str(popup["text"]).split("\n"):
            var line_width: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, pop_size).x
            var at: Vector2 = Vector2(float_pos.x - line_width * 0.5, line_y)
            draw_string(font, at + Vector2(1, 1), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, pop_size, pop_shadow)
            draw_string(font, at, str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, pop_size, pop_color)
            line_y += pop_size + 3.0
    if selected_request_id.is_empty() or not actors.has(selected_request_id):
        return
    var actor: Dictionary = actors[selected_request_id]
    if str(actor.get("state", "")) != "WAITING":
        return
    var dialogue: String = str(actor.get("dialogue", ""))
    if dialogue.is_empty():
        return
    var actor_pos: Vector2 = actor["pos"]
    var head: Vector2 = origin + (actor_pos + Vector2(8.0, 0.0)) * scale_factor
    _draw_bubble(font, head, dialogue, scale_factor, origin)

func _draw_bubble(font: Font, head: Vector2, dialogue: String, scale_factor: float, origin: Vector2) -> void:
    var font_size: int = int(clampf(round(scale_factor * 4.0), 12.0, 18.0))
    var max_text_width: float = clampf(size.x * 0.62, 120.0, 380.0)
    var shown: String = dialogue
    var text_width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    if text_width > max_text_width:
        while shown.length() > 8 and text_width > max_text_width:
            shown = shown.substr(0, shown.length() - 1)
            text_width = font.get_string_size(shown + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
        shown = shown.rstrip(" ,.") + "…"
        text_width = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var bubble_size: Vector2 = Vector2(text_width + 24.0, font_size + 16.0)
    var room_rect: Rect2 = Rect2(origin, Vector2(256, 192) * scale_factor)
    var bubble_pos: Vector2 = Vector2(head.x - bubble_size.x * 0.5, head.y - bubble_size.y - 9.0)
    bubble_pos.x = clampf(bubble_pos.x, room_rect.position.x + 4.0, room_rect.end.x - bubble_size.x - 4.0)
    bubble_pos.y = clampf(bubble_pos.y, room_rect.position.y + 4.0, room_rect.end.y - bubble_size.y - 4.0)
    var bubble: Rect2 = Rect2(bubble_pos, bubble_size)
    draw_style_box(_bubble_box(), bubble)
    var tail_x: float = clampf(head.x, bubble.position.x + 14.0, bubble.end.x - 14.0)
    draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 7.0, bubble.end.y - 2.0), Vector2(tail_x + 7.0, bubble.end.y - 2.0), Vector2(tail_x, bubble.end.y + 8.0)]), Color("584648"))
    draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 4.0, bubble.end.y - 1.0), Vector2(tail_x + 4.0, bubble.end.y - 1.0), Vector2(tail_x, bubble.end.y + 5.0)]), Color("fff1d2"))
    draw_string(font, Vector2(bubble.position.x + 12.0, bubble.position.y + 8.0 + font_size * 0.85), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("493a39"))

func _bubble_box() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("fff1d2")
    style.border_color = Color("584648")
    style.set_border_width_all(2)
    style.set_corner_radius_all(6)
    return style

func set_selected_request(id: String) -> void:
    selected_request_id = id
    queue_redraw()

func celebrate(request_id: String) -> void:
    if actors.has(request_id):
        celebrations[request_id] = 0.9
        queue_redraw()

func float_text(request_id: String, text: String, color: Color) -> void:
    ## A short-lived popup above a guest ("+45 XP", "walked out").
    for popup in floats:
        if str(popup["id"]) == request_id and float(popup["t"]) < 0.05:
            popup["text"] = str(popup["text"]) + "\n" + text
            return
    floats.append({"id": request_id, "text": text, "color": color, "t": 0.0})
    while floats.size() > 5:
        floats.pop_front()
    queue_redraw()

func confetti() -> void:
    ## End-of-shift confetti. Skipped entirely in reduced-motion mode.
    if reduced_motion:
        return
    confetti_pieces.clear()
    var colors: Array[Color] = [Color("e7ba72"), Color("c86652"), Color(1.0, 0.95, 0.86), Color("6da18b")]
    for i in range(38):
        confetti_pieces.append({
            "pos": Vector2(randf_range(16.0, 240.0), randf_range(-16.0, -2.0)),
            "vel": Vector2(randf_range(-9.0, 9.0), randf_range(22.0, 46.0)),
            "size": Vector2(randf_range(2.0, 3.0), randf_range(2.0, 4.0)),
            "color": colors[i % colors.size()],
            "phase": randf_range(0.0, TAU),
            "life": randf_range(1.4, 2.1),
        })
    queue_redraw()

func _draw_hearts(pos: Vector2, fade: float) -> void:
    ## A small pixel heart over a guest who just got served; it fades as they leave.
    var color: Color = Color(0.83, 0.39, 0.35, fade)
    var top: Vector2 = pos + Vector2(4, -34)
    draw_rect(Rect2(top, Vector2(2, 2)), color)
    draw_rect(Rect2(top + Vector2(4, 0), Vector2(2, 2)), color)
    draw_rect(Rect2(top + Vector2(0, 2), Vector2(8, 2)), color)
    draw_rect(Rect2(top + Vector2(1, 4), Vector2(6, 2)), color)
    draw_rect(Rect2(top + Vector2(2, 6), Vector2(4, 2)), color)
    draw_rect(Rect2(top + Vector2(3, 8), Vector2(2, 2)), color)

func draw_ellipse_shadow(pos: Vector2) -> void:
    _draw_shadow(pos)

func _draw_shadow(pos: Vector2) -> void:
    draw_rect(Rect2(pos-Vector2(7,1),Vector2(14,3)),Color(0.3,0.2,0.2,0.18))

func _shadow() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.25,0.15,0.2,0.18)
    style.set_corner_radius_all(8)
    return style
