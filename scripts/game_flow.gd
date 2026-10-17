extends Node
## Scene-local flow. The store owns simulation; this coordinator owns entry/pause/tutorial.
enum State { WELCOME, TUTORIAL, PRACTICE, RUSH, ONLINE_LOBBY, ONLINE }
var state: State = State.WELCOME
var host: Control
var welcome: Control
var strip: PanelContainer
var prompt: Label
var step: int = 0
var tutorial_ticket: int = -1
var _guiding: bool = false

func _ready() -> void:
    welcome = preload("res://scripts/welcome_screen.gd").new()
    welcome.name = "WelcomeScreen"
    welcome.host = host
    welcome.action_requested.connect(_action)
    host.add_child(welcome)
    strip = host._panel(Color("fff3d2"))
    strip.name = "TutorialStrip"
    strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    strip.offset_left = 12
    strip.offset_right = -12
    strip.offset_top = 8
    strip.offset_bottom = 104
    host.add_child(strip)
    var row: HBoxContainer = host._row(8)
    strip.add_child(row)
    prompt = host._label("",17)
    prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(prompt)
    var skip: Button = host._button("Skip\nTutorial",func(): show_welcome(),false,"SkipTutorial")
    skip.custom_minimum_size = Vector2(78,58)
    row.add_child(skip)
    OrderStore.cart_changed.connect(_cart_changed)
    OrderStore.orders_changed.connect(_orders_changed)
    KitchenSync.changed.connect(_sync_changed)
    host._sync_dialog.visibility_changed.connect(func():
        if state == State.ONLINE_LOBBY and not host._sync_dialog.visible and not KitchenSync.active: show_welcome()
    )
    show_welcome()

func _enter(next: State) -> void:
    state = next
    welcome.visible = state == State.WELCOME
    strip.visible = state == State.TUTORIAL
    host._margin.visible = state != State.WELCOME
    host._margin.offset_top = 112 if state == State.TUTORIAL else 0
    OrderStore.gameplay_running = state in [State.PRACTICE,State.RUSH,State.TUTORIAL] and not KitchenSync.active
    OrderStore.set_process(true) # The store's explicit guard remains authoritative.
    for id in ["Welcome","WalkIn","FreePlay","RushHour","OpenSync","Options"]:
        var control: Button = host.find_child(id,true,false)
        if control != null: control.disabled = state == State.TUTORIAL
    if state != State.TUTORIAL: host._stage_row.get_parent().show()

func show_welcome(success: bool = false) -> void:
    var was_tutorial: bool = state == State.TUTORIAL
    _enter(State.WELCOME)
    if was_tutorial:
        OrderStore.end_tutorial(success)
        host.selected_request = ""
        host._name.clear()
        host._table.clear()
        host._world.set_selected_request("")
        host._world.actors.clear()
        host._refresh_all()
    welcome.show_welcome(success)

func _action(action: String) -> void:
    if action == "SETTINGS":
        host._options.popup_centered(Vector2i(400,440))
        return
    if action == "RESUME":
        _enter(State.ONLINE if KitchenSync.active else (State.RUSH if OrderStore.shift.mode == "RUSH" else State.PRACTICE))
        host._tab_order.grab_focus()
        return
    if KitchenSync.active or KitchenSync.busy:
        if action == "ONLINE":
            _enter(State.ONLINE)
            host._open_sync()
        else:
            welcome.copy.text = "Disconnect the online room before starting an offline shift or tutorial. Your room remains available."
        return
    match action:
        "TUTORIAL": start_tutorial()
        "ONLINE":
            _enter(State.ONLINE_LOBBY)
            host._open_sync()
        "RUSH", "FREE":
            if not OrderStore.orders.is_empty() or not OrderStore.cart.is_empty() or (OrderStore.shift.mode == "RUSH" and OrderStore.shift.elapsed > 0):
                host._ask_shift(action)
            else:
                host._next_mode = action
                host._start_shift()

func playing(mode: String) -> void:
    _enter(State.RUSH if mode == "RUSH" else State.PRACTICE)

func start_tutorial() -> void:
    if KitchenSync.active or KitchenSync.busy: return
    step = 0
    tutorial_ticket = -1
    OrderStore.begin_tutorial()
    host.selected_request = ""
    host.search_query = ""
    var search: LineEdit = host.find_child("Search",true,false)
    search.clear()
    host._select_category("All")
    host._name.clear()
    host._table.clear()
    host._world.actors.clear()
    host._world.set_selected_request("R1")
    host._shown_result = ""
    host._refresh_all()
    host._switch_screen("ORDER")
    _enter(State.TUTORIAL)
    _guide()

func customer_selected(id: String) -> void:
    if state != State.TUTORIAL or id != "R1" or step > 2: return
    step = 1
    _cart_changed()

func _cart_changed() -> void:
    if state != State.TUTORIAL or step not in [1,2]: return
    step = 2 if OrderStore.shift.matches("R1",OrderStore.cart) else 1
    _guide()

func _orders_changed() -> void:
    if state != State.TUTORIAL or OrderStore.orders.is_empty(): return
    tutorial_ticket = int(OrderStore.orders[0]["id"])
    match str(OrderStore.orders[0]["status"]):
        "NEW": step = 3
        "PREPARING": step = 5
        "DONE":
            step = 6
            prompt.text = "First order complete! Your guest is happy."
            _finish_later()
            return
    _guide()

func station_changed(station: String) -> void:
    if state != State.TUTORIAL: return
    if station == "KITCHEN" and step < 3:
        host.call_deferred("_switch_screen","ORDER")
        host._notify("Match Amelia's recipe first; her kitchen ticket comes next.")
        return
    if station == "KITCHEN" and step == 3: step = 4
    if step >= 3: _guide()

func _finish_later() -> void:
    await get_tree().create_timer(0.8).timeout
    if state == State.TUTORIAL and step == 6: show_welcome(true)

func _guide() -> void:
    if not _guiding:
        _guiding = true
        call_deferred("_show_guide")

func _show_guide() -> void:
    # Containers finish sorting new receipt/ticket controls after deferred calls.
    await get_tree().process_frame
    await get_tree().process_frame
    _guiding = false
    if state != State.TUTORIAL: return
    host._stage_row.get_parent().visible = step == 0 or not host._phone_mode
    var target: Control
    match step:
        0:
            prompt.text = "1/5 · Meet Amelia\nTap the highlighted guest or Take order. No clock, no walkouts."
            target = host.find_child("Request_R1",true,false)
        1:
            var extras: bool = false
            var extra_id: String = ""
            for id in OrderStore.cart:
                if id not in ["latte","croissant"] or int(OrderStore.cart[id]) > 1:
                    extras = true
                    extra_id = str(id)
            prompt.text = "2/5 · Her usual, please\nAdd ONE Honey Latte and ONE Butter Croissant."
            if extras: prompt.text = "Easy fix · use − on the receipt to remove extras. Your order is safe."
            target = host.find_child("Minus_"+extra_id,true,false) if extras else host.find_child("Add_latte" if not OrderStore.cart.has("latte") else "Add_croissant",true,false)
        2:
            prompt.text = "Recipe matched!\n3/5 · Send Amelia's ticket to the kitchen."
            target = host._send
        3:
            prompt.text = "Ticket printed!\n4/5 · Open the Kitchen rail to find Amelia's order."
            target = host._tab_kitchen
        4:
            prompt.text = "There's her ticket!\n4/5 · Tap Start preparing. The kitchen needs you."
            target = host.find_child("Advance_%d" % tutorial_ticket,true,false)
        5:
            prompt.text = "5/5 · Make each requested item.\nFollow the equipment, then serve the finished tray."
            target = host.find_child("Advance_%d" % tutorial_ticket,true,false)
    if step >= 3 and host._screen != "KITCHEN":
        prompt.text = "Your ticket is safe.\nOpen Kitchen to continue preparing Amelia's order."
        target = host._tab_kitchen
    if target != null:
        if is_instance_valid(host.prep_station) and host.prep_station.visible: return
        target.grab_focus()
        var reveal: Control = target.get_parent().get_parent() if step == 1 and target.name.begins_with("Add_") else target
        var parent: Node = target.get_parent()
        while parent != null:
            if parent is ScrollContainer: parent.ensure_control_visible(reveal)
            parent = parent.get_parent()

func _sync_changed() -> void:
    if state in [State.ONLINE_LOBBY,State.ONLINE] and KitchenSync.active: _enter(State.ONLINE)
    OrderStore.gameplay_running = state in [State.PRACTICE,State.RUSH,State.TUTORIAL] and not KitchenSync.active
