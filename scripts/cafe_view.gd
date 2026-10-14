extends Control
## An animated, live view of the customers in the authoritative shift model.

var room: Texture2D
var sprites: Dictionary = {}
var actors: Dictionary = {}
var clock: float = 0.0
var reduced_motion: bool = false
var selected_request_id: String = ""

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists("res://assets/licensed/cafe.png"):
        room = load("res://assets/licensed/cafe.png")
    for name in ["Amelia", "Adam", "Alex", "Bob", "Lucy", "Ash"]:
        var path: String = "res://assets/licensed/%s_idle_anim.png" % name
        if ResourceLoader.exists(path):
            sprites[name] = load(path)

func _process(delta: float) -> void:
    clock += delta
    var ids: Array[String] = []
    var index: int = 0
    for request in OrderStore.shift.requests:
        var id: String = str(request["id"])
        ids.append(id)
        var goal: Vector2 = Vector2(112 + index * 33, 133 + index * 7)
        if not actors.has(id):
            actors[id] = {"id": id, "pos": Vector2(248, 167), "name": str(request["name"]), "state": "WAITING", "patience": 65.0}
        actors[id]["pos"] = goal if reduced_motion else (actors[id]["pos"] as Vector2).move_toward(goal, delta * 30)
        actors[id]["state"] = str(request["state"])
        actors[id]["patience"] = float(request["patience"])
        index += 1
    for id in actors.keys():
        if id not in ids:
            actors[id]["pos"] = (actors[id]["pos"] as Vector2).move_toward(Vector2(265, 166), delta * 65)
            if float(actors[id]["pos"].x) >= 260:
                actors.erase(id)
    queue_redraw()

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
        _draw_actor(str(actor["name"]), actor["pos"], str(actor["state"]), str(actor.get("id", "")), float(actor.get("patience", 65.0)))
    for i in range(3):
        var t: float = 0.5 if reduced_motion else fmod(clock * 0.5 + i * 0.33, 1.0)
        draw_line(Vector2(139 + i * 3, 63 - t * 15), Vector2(141 + i * 3, 59 - t * 15), Color(1, 0.94, 0.8, (1-t)*0.65), 1)
    draw_set_transform(Vector2.ZERO)

func _draw_actor(name: String, pos: Vector2, state: String, request_id: String = "", patience: float = 65.0) -> void:
    draw_ellipse_shadow(pos + Vector2(8,28))
    if sprites.has(name):
        var frame: int = 0 if reduced_motion else int(clock * 5) % 6
        draw_texture_rect_region(sprites[name], Rect2(pos, Vector2(16,32)), Rect2(frame*16,0,16,32))
    else:
        draw_rect(Rect2(pos+Vector2(3,4),Vector2(10,12)),Color("daa875"))
        draw_rect(Rect2(pos+Vector2(2,17),Vector2(12,12)),Color("689d8f"))
    if state == "BARISTA":
        return
    var bubble: Rect2 = Rect2(pos + Vector2(-1,-9),Vector2(19,12))
    var selected: bool = request_id == selected_request_id and not request_id.is_empty()
    var bubble_color: Color = Color("e7ba72") if selected else Color("fff1d2")
    draw_rect(bubble.grow(1), Color("584648"))
    draw_rect(bubble, bubble_color)
    draw_rect(Rect2(pos+Vector2(8,2),Vector2(2,2)),bubble_color)
    if state == "KITCHEN":
        draw_rect(Rect2(pos+Vector2(5,-6),Vector2(7,5)),Color("639788"))
        draw_line(pos+Vector2(7,-7),pos+Vector2(7,-9),Color("639788"),1)
        draw_line(pos+Vector2(10,-7),pos+Vector2(10,-9),Color("639788"),1)
    elif patience <= 20.0:
        draw_rect(Rect2(pos+Vector2(7,-7),Vector2(2,5)),Color("b84f41"))
        draw_rect(Rect2(pos+Vector2(7,-1),Vector2(2,2)),Color("b84f41"))
    elif selected:
        draw_rect(Rect2(pos+Vector2(5,-6),Vector2(7,5)),Color("a84f41"))
        draw_rect(Rect2(pos+Vector2(6,-7),Vector2(5,1)),Color("a84f41"))
    else:
        for i in range(3):
            draw_rect(Rect2(pos+Vector2(4+i*4,-4),Vector2(2,2)),Color("b96858"))

func set_selected_request(id: String) -> void:
    selected_request_id = id
    queue_redraw()

func draw_ellipse_shadow(pos: Vector2) -> void:
    _draw_shadow(pos)

func _draw_shadow(pos: Vector2) -> void:
    draw_rect(Rect2(pos-Vector2(7,1),Vector2(14,3)),Color(0.3,0.2,0.2,0.18))

func _shadow() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.25,0.15,0.2,0.18)
    style.set_corner_radius_all(8)
    return style
