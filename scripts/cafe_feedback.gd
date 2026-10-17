extends Node
## Purposeful cues and compact event notices. No simulation or reward ownership.
var host: Control
var banner: Label
var arrivals: int = 0
var last_event: String = ""
func _ready() -> void:
    banner = host._label("",16,host.GOLD)
    banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var page: VBoxContainer = host._margin.get_child(0)
    page.add_child(banner)
    page.move_child(banner,1)
    banner.hide()
    arrivals = OrderStore.shift.sequence
func _process(_delta: float) -> void:
    var run: RefCounted = OrderStore.shift
    var enabled: bool = OrderStore.gameplay_running and run.mode == "RUSH" and not KitchenSync.active
    banner.visible = enabled and not run.events.notice.is_empty()
    banner.text = run.events.notice
    host.prep_station.event_label.text = run.events.notice
    host.prep_station.event_label.visible = banner.visible
    if not enabled: return
    if run.sequence > arrivals: host._play("arrival")
    arrivals = run.sequence
    if last_event != run.events.active_id:
        last_event = run.events.active_id
        if last_event != "":
            host._play({"LUNCH":"lunch","VIP":"vip","PERFECT":"challenge"}[last_event])
            host._world.float_text("",{"LUNCH":"Lunch rush!","VIP":"VIP at the door!","PERFECT":"Perfect service!"}[last_event],host.GOLD)
func reset() -> void:
    arrivals = 0
    last_event = ""
