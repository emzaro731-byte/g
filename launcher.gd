extends Node2D

const DESIGN_SIZE := Vector2(1170, 2532)
const BG_TOP := Color("#101a38")
const BG_BOTTOM := Color("#050817")
const GLASS := Color(1, 1, 1, 0.12)
const WHITE := Color("#F7F8FF")
const MUTED := Color("#AEB7D6")

var root_ui: Control
var app_overlay: Panel
var search_panel: Panel
var control_panel: Panel
var page := 0
var pages := 2
var apps := [
	{"name":"Phone", "glyph":"☎", "color":Color("#22C55E")},
	{"name":"Messages", "glyph":"●", "color":Color("#34D399")},
	{"name":"Camera", "glyph":"◉", "color":Color("#1F2937")},
	{"name":"Photos", "glyph":"✿", "color":Color("#F472B6")},
	{"name":"Maps", "glyph":"⌖", "color":Color("#38BDF8")},
	{"name":"Music", "glyph":"♫", "color":Color("#F43F5E")},
	{"name":"Weather", "glyph":"☀", "color":Color("#38BDF8")},
	{"name":"Clock", "glyph":"◷", "color":Color("#111827")},
	{"name":"Notes", "glyph":"≡", "color":Color("#FBBF24")},
	{"name":"Files", "glyph":"▣", "color":Color("#60A5FA")},
	{"name":"Settings", "glyph":"⚙", "color":Color("#64748B")},
	{"name":"Browser", "glyph":"◎", "color":Color("#2563EB")}
]

func _ready() -> void:
	get_viewport().size_changed.connect(_on_resize)
	_build_launcher()
	_on_resize()

func _on_resize() -> void:
	if root_ui:
		root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_launcher() -> void:
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_ui)

	var background := ColorRect.new()
	background.color = BG_BOTTOM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(background)

	var glow := ColorRect.new()
	glow.color = Color(0.08, 0.16, 0.38, 0.75)
	glow.position = Vector2(0, 0)
	glow.size = Vector2(DESIGN_SIZE.x, 900)
	root_ui.add_child(glow)

	_build_status_bar()
	_build_header()
	_build_widgets()
	_build_app_grid()
	_build_page_dots()
	_build_dock()
	_build_home_indicator()
	_build_search_panel()
	_build_control_panel()

func _label(text: String, size: int, color := WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_status_bar() -> void:
	var time := _label("9:41", 34, WHITE)
	time.position = Vector2(58, 38)
	root_ui.add_child(time)

	var right := _label("▮▮▮  ᯤ  ▰", 25, WHITE)
	right.position = Vector2(930, 42)
	root_ui.add_child(right)

func _build_header() -> void:
	var title := _label("Monday, September 7", 25, MUTED)
	title.position = Vector2(55, 160)
	root_ui.add_child(title)

	var greeting := _label("Good evening", 54, WHITE)
	greeting.position = Vector2(52, 198)
	root_ui.add_child(greeting)

	var search_button := Button.new()
	search_button.text = "⌕   Search"
	search_button.position = Vector2(52, 292)
	search_button.size = Vector2(1066, 82)
	search_button.add_theme_font_size_override("font_size", 28)
	search_button.add_theme_color_override("font_color", MUTED)
	search_button.add_theme_stylebox_override("normal", _box(Color(1,1,1,0.11), 32))
	search_button.pressed.connect(_toggle_search)
	root_ui.add_child(search_button)

func _build_widgets() -> void:
	var weather := Panel.new()
	weather.position = Vector2(52, 405)
	weather.size = Vector2(510, 235)
	weather.add_theme_stylebox_override("panel", _box(GLASS, 38))
	root_ui.add_child(weather)
	var wt := _label("Port Harcourt", 23, MUTED)
	wt.position = Vector2(28, 25)
	weather.add_child(wt)
	var temp := _label("28°", 64, WHITE)
	temp.position = Vector2(25, 65)
	weather.add_child(temp)
	var condition := _label("Partly cloudy", 24, WHITE)
	condition.position = Vector2(29, 145)
	weather.add_child(condition)
	var sun := _label("☼", 75, Color("#FCD34D"))
	sun.position = Vector2(380, 52)
	weather.add_child(sun)

	var battery := Panel.new()
	battery.position = Vector2(578, 405)
	battery.size = Vector2(540, 235)
	battery.add_theme_stylebox_override("panel", _box(GLASS, 38))
	root_ui.add_child(battery)
	var bt := _label("Battery", 23, MUTED)
	bt.position = Vector2(28, 25)
	battery.add_child(bt)
	var bval := _label("82%", 60, WHITE)
	bval.position = Vector2(25, 65)
	battery.add_child(bval)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1,1,1,0.12)
	bar_bg.position = Vector2(28, 158)
	bar_bg.size = Vector2(480, 18)
	battery.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Color("#4ADE80")
	bar.position = Vector2(28, 158)
	bar.size = Vector2(394, 18)
	battery.add_child(bar)

func _build_app_grid() -> void:
	var start := Vector2(65, 705)
	var col_w := 170.0
	var row_h := 190.0
	for i in apps.size():
		var p := i
		var col := p % 6
		var row := p / 6
		var icon := Button.new()
		icon.position = start + Vector2(col * col_w, row * row_h)
		icon.size = Vector2(120, 120)
		icon.text = apps[i].glyph
		icon.add_theme_font_size_override("font_size", 54)
		icon.add_theme_color_override("font_color", WHITE)
		icon.add_theme_stylebox_override("normal", _box(apps[i].color, 30))
		icon.add_theme_stylebox_override("hover", _box(apps[i].color.lightened(0.12), 30))
		icon.pressed.connect(_open_app.bind(apps[i].name))
		root_ui.add_child(icon)
		var name := _label(apps[i].name, 19, WHITE)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.position = icon.position + Vector2(-15, 128)
		name.size = Vector2(150, 35)
		root_ui.add_child(name)

func _build_page_dots() -> void:
	var dots := _label("●  ○", 19, WHITE)
	dots.position = Vector2(548, 1485)
	root_ui.add_child(dots)

func _build_dock() -> void:
	var dock := Panel.new()
	dock.position = Vector2(42, 1745)
	dock.size = Vector2(1086, 165)
	dock.add_theme_stylebox_override("panel", _box(Color(1,1,1,0.16), 45))
	root_ui.add_child(dock)
	var dock_apps := ["☎", "●", "◎", "⚙"]
	var dock_colors := [Color("#22C55E"), Color("#34D399"), Color("#2563EB"), Color("#64748B")]
	for i in 4:
		var b := Button.new()
		b.position = Vector2(45 + i * 250, 20)
		b.size = Vector2(120, 120)
		b.text = dock_apps[i]
		b.add_theme_font_size_override("font_size", 52)
		b.add_theme_stylebox_override("normal", _box(dock_colors[i], 30))
		b.pressed.connect(_open_app.bind(apps[i].name))
		dock.add_child(b)

func _build_home_indicator() -> void:
	var home := Button.new()
	home.position = Vector2(390, 1960)
	home.size = Vector2(390, 42)
	home.text = ""
	home.add_theme_stylebox_override("normal", _box(Color(1,1,1,0.85), 20))
	home.pressed.connect(_close_overlay)
	root_ui.add_child(home)

func _build_search_panel() -> void:
	search_panel = Panel.new()
	search_panel.position = Vector2(35, 120)
	search_panel.size = Vector2(1100, 1850)
	search_panel.visible = false
	search_panel.add_theme_stylebox_override("panel", _box(Color("#0B1025"), 42))
	root_ui.add_child(search_panel)
	var title := _label("Search", 48, WHITE)
	title.position = Vector2(40, 45)
	search_panel.add_child(title)
	var input := LineEdit.new()
	input.placeholder_text = "Search apps"
	input.position = Vector2(40, 120)
	input.size = Vector2(1020, 82)
	input.add_theme_font_size_override("font_size", 28)
	search_panel.add_child(input)
	var hint := _label("Try: Settings, Camera, Music...", 22, MUTED)
	hint.position = Vector2(45, 225)
	search_panel.add_child(hint)
	var close := Button.new()
	close.text = "Done"
	close.position = Vector2(900, 40)
	close.size = Vector2(150, 60)
	close.pressed.connect(_toggle_search)
	search_panel.add_child(close)

func _build_control_panel() -> void:
	control_panel = Panel.new()
	control_panel.position = Vector2(45, 150)
	control_panel.size = Vector2(1080, 950)
	control_panel.visible = false
	control_panel.add_theme_stylebox_override("panel", _box(Color(0.06,0.09,0.20,0.98), 45))
	root_ui.add_child(control_panel)
	var title := _label("Control Center", 44, WHITE)
	title.position = Vector2(42, 35)
	control_panel.add_child(title)
	var items := ["Wi‑Fi", "Bluetooth", "Airplane Mode", "Focus", "Brightness", "Volume"]
	for i in items.size():
		var c := Button.new()
		c.text = items[i]
		c.position = Vector2(40 + (i % 2) * 500, 130 + (i / 2) * 150)
		c.size = Vector2(450, 110)
		c.add_theme_font_size_override("font_size", 24)
		c.add_theme_stylebox_override("normal", _box(Color(1,1,1,0.11), 28))
		control_panel.add_child(c)
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(40, 820)
	close.size = Vector2(1000, 70)
	close.pressed.connect(_toggle_control)
	control_panel.add_child(close)

func _open_app(app_name: String) -> void:
	if app_overlay:
		app_overlay.queue_free()
	app_overlay = Panel.new()
	app_overlay.position = Vector2(35, 100)
	app_overlay.size = Vector2(1100, 1800)
	app_overlay.add_theme_stylebox_override("panel", _box(Color("#0A1022"), 42))
	root_ui.add_child(app_overlay)
	var title := _label(app_name, 46, WHITE)
	title.position = Vector2(42, 40)
	app_overlay.add_child(title)
	var message := _label("This is a launcher preview.\nConnect this icon to a native Android intent\nwhen packaging the project as a real launcher.", 28, MUTED)
	message.position = Vector2(42, 180)
	message.size = Vector2(1000, 250)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app_overlay.add_child(message)
	var close := Button.new()
	close.text = "‹  Home"
	close.position = Vector2(40, 1660)
	close.size = Vector2(1000, 80)
	close.pressed.connect(_close_app)
	app_overlay.add_child(close)

func _close_app() -> void:
	if app_overlay:
		app_overlay.queue_free()
		app_overlay = null

func _toggle_search() -> void:
	search_panel.visible = not search_panel.visible
	if search_panel.visible:
		control_panel.visible = false
		_close_app()

func _toggle_control() -> void:
	control_panel.visible = not control_panel.visible
	if control_panel.visible:
		search_panel.visible = false
		_close_app()

func _close_overlay() -> void:
	search_panel.visible = false
	control_panel.visible = false
	_close_app()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if event.position.y < 120 and event.position.x > 900:
			_toggle_control()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_overlay()

func _box(color: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(1,1,1,0.08)
	return box
