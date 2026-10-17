extends ConfirmationDialog
## A scrollable result slip; long statistics and achievements fit short viewports.
var content: VBoxContainer
var copy: Label
var scroll: ScrollContainer
var report_text: String = ""
func _init() -> void:
    scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",12)
    scroll.add_child(content)
    copy = Label.new()
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.add_theme_color_override("font_color",Color("493a39"))
    copy.add_theme_font_size_override("font_size",16)
    content.add_child(copy)
func present() -> void:
    get_label().hide()
    copy.text = report_text
    var available: Vector2i = Vector2i(get_parent().get_viewport_rect().size)-Vector2i(40,100)
    scroll.custom_minimum_size = Vector2(mini(460,available.x-40),maxi(100,mini(420,available.y-100)))
    popup_centered(Vector2i(mini(520,available.x),mini(580,available.y)))
