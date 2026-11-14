extends Control

## Start menu (Play / Guide / Leaderboard + game name), 5 tries per player,
## "tries remaining" message after every meme, game over and a leaderboard.
## All screens are built in code, so there is nothing to set up in the editor.
##
## The leaderboard is saved on THIS computer (user://leaderboard.json).

const MAX_TRIES := 5
const SAVE_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 20
const GOLD := Color(0.93, 0.78, 0.40)
const NAVY := Color(0.05, 0.07, 0.11, 0.96)
const INK := Color(0.93, 0.94, 0.96)
const MUTED := Color(0.62, 0.67, 0.76)

enum State { MENU, PLAYING, MEME, GAME_OVER }

var state: State = State.MENU
var player_name: String = ""
var tries_left: int = MAX_TRIES
var best_m: float = 0.0

var _menu: Control
var _guide: Control
var _board: Control
var _over: Control
var _name_edit: LineEdit
var _name_error: Label
var _board_grid: GridContainer
var _over_summary: Label
var _over_grid: GridContainer
var _hud: Label
var _banner: Label

@onready var ronaldo = get_node("../../Ronaldo")
@onready var indicator = get_node("../TimingBarUI/BarGraphic/Indicator")
@onready var memes = get_node("../MilestoneManager")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	ronaldo.jumped.connect(_on_jumped)
	ronaldo.landed.connect(_on_landed)
	_show_menu()

# ---------------------------------------------------------------- game flow

func _start_game() -> void:
	tries_left = MAX_TRIES
	best_m = 0.0
	_hide_screens()
	_hud.visible = true
	_update_hud()
	state = State.PLAYING
	indicator.reset_round()
	indicator.set_process(true)
	ronaldo.enable_input(0.35)

func _on_jumped(_tier: int) -> void:
	tries_left -= 1
	_update_hud()

# Ronaldo touched the trampoline again: stop him, play the meme, then tell the
# player how many tries are left.
func _on_landed(peak_m: float) -> void:
	ronaldo.disable_input()          # runs before the first await, so no extra jump
	if state != State.PLAYING:
		return
	state = State.MEME
	best_m = maxf(best_m, peak_m)
	_update_hud()

	await memes.play_for_peak(peak_m)
	if state != State.MEME:
		return

	if tries_left <= 0:
		await _show_banner("NO TRIES LEFT!", 1.4)
		_game_over()
	else:
		var word := "TRY" if tries_left == 1 else "TRIES"
		await _show_banner("%d %s REMAINING" % [tries_left, word], 1.4)
		state = State.PLAYING
		indicator.reset_round()
		indicator.set_process(true)
		ronaldo.enable_input(0.3)

func _show_banner(text: String, seconds: float) -> void:
	_banner.text = text
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.85, 0.85)
	_banner.modulate.a = 0.0
	_banner.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	_banner.visible = false

func _game_over() -> void:
	state = State.GAME_OVER
	_hud.visible = false
	_save_score(player_name, best_m)
	_over_summary.text = "%s  -  best jump: %.1f m" % [player_name, best_m]
	_fill_board(_over_grid, player_name)
	_fade_in(_over)

func _show_menu() -> void:
	state = State.MENU
	ronaldo.disable_input()
	indicator.set_process(false)
	_hud.visible = false
	_hide_screens()
	_fade_in(_menu)
	_name_error.visible = false
	_name_edit.grab_focus.call_deferred()

func _update_hud() -> void:
	_hud.text = "%s     Tries left: %d/%d     Best: %.1f m" % [player_name, tries_left, MAX_TRIES, best_m]

func _hide_screens() -> void:
	for s in [_menu, _guide, _board, _over]:
		s.visible = false

func _fade_in(screen: Control) -> void:
	screen.visible = true
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.25)

# ---------------------------------------------------------------- buttons

func _on_play_pressed() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		_name_error.visible = true
		_name_edit.grab_focus()
		return
	player_name = n
	_start_game()

func _on_name_submitted(_text: String) -> void:
	_on_play_pressed()

func _on_guide_pressed() -> void:
	_hide_screens()
	_fade_in(_guide)

func _on_board_pressed() -> void:
	_fill_board(_board_grid)
	_hide_screens()
	_fade_in(_board)

# ---------------------------------------------------------------- leaderboard

func _load_board() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		return data
	return []

# One row per name: keeps that name's best score.
func _save_score(pname: String, score: float) -> void:
	var entries: Array = _load_board()
	var found := false
	for e in entries:
		if str(e.get("name", "")).to_lower() == pname.to_lower():
			found = true
			if score > float(e.get("score", 0.0)):
				e["score"] = score
			break
	if not found:
		entries.append({"name": pname, "score": score})
	entries.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(entries))

func _fill_board(grid: GridContainer, highlight: String = "") -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	grid.add_child(_cell("#", MUTED, HORIZONTAL_ALIGNMENT_CENTER, 50))
	grid.add_child(_cell("NAME", MUTED, HORIZONTAL_ALIGNMENT_LEFT, 220))
	grid.add_child(_cell("BEST", MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 110))

	var entries: Array = _load_board()
	if entries.is_empty():
		grid.add_child(_cell("", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 50))
		grid.add_child(_cell("No scores yet", Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 220))
		grid.add_child(_cell("", Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 110))
		return

	for i in mini(entries.size(), 10):
		var e: Dictionary = entries[i]
		var col := GOLD if str(e["name"]) == highlight else INK
		grid.add_child(_cell("%d" % (i + 1), col, HORIZONTAL_ALIGNMENT_CENTER, 50))
		grid.add_child(_cell(str(e["name"]), col, HORIZONTAL_ALIGNMENT_LEFT, 220))
		grid.add_child(_cell("%.1f m" % float(e["score"]), col, HORIZONTAL_ALIGNMENT_RIGHT, 110))

# ---------------------------------------------------------------- UI building

func _build_ui() -> void:
	# HUD: top-left, just under the timing bar
	_hud = _label("", 18)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.position = Vector2(90, 55)
	_hud.visible = false

	# Banner ("2 TRIES REMAINING"): wide, near the top of the screen
	_banner = _label("", 48, GOLD)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_banner.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	_banner.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	_banner.set_anchor_and_offset(SIDE_TOP, 0.2, 0.0)
	_banner.set_anchor_and_offset(SIDE_BOTTOM, 0.2, 90.0)
	_banner.visible = false

	# ---- Start menu
	_menu = _make_screen()
	var m := _make_card(_menu, 440)
	m.add_child(_label("RONALDO'S TRAMPOLINE", 34, GOLD))
	m.add_child(_label("HOW HIGH CAN YOU BOUNCE?", 15, MUTED))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Type your game name"
	_name_edit.max_length = 14
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 52)
	_name_edit.add_theme_font_size_override("font_size", 22)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(1, 1, 1, 0.06)
	le.set_corner_radius_all(12)
	le.set_border_width_all(1)
	le.border_color = Color(1, 1, 1, 0.18)
	le.set_content_margin_all(10)
	_name_edit.add_theme_stylebox_override("normal", le)
	var lef := le.duplicate() as StyleBoxFlat
	lef.border_color = GOLD
	_name_edit.add_theme_stylebox_override("focus", lef)
	_name_edit.text_submitted.connect(_on_name_submitted)
	m.add_child(_name_edit)
	_name_error = _label("Please type a game name first!", 18, Color(1.0, 0.4, 0.4))
	m.add_child(_name_error)
	m.add_child(_button("PLAY", _on_play_pressed))
	m.add_child(_button("GUIDE", _on_guide_pressed))
	m.add_child(_button("LEADERBOARD", _on_board_pressed))

	# ---- Guide
	_guide = _make_screen()
	var g := _make_card(_guide, 620)
	g.add_child(_label("HOW TO PLAY", 36, GOLD))
	var text := Label.new()
	text.text = "\n".join([
		"1.  Type your game name and press PLAY.",
		"2.  A bar at the top moves left and right. Press SPACE (or ENTER) when the line is in the GREEN middle. The closer to the center, the higher Ronaldo jumps.",
		"3.  Ronaldo flies up and lands back on the trampoline. The ruler on the right shows how high he got.",
		"4.  When he lands, a short meme plays for your highest point. Reach 100 m for the secret GTA \"Mission Passed\"!",
		"5.  You get 5 tries. After every meme the game tells you how many tries are left.",
		"6.  After the 5th try your best jump goes on the leaderboard. Aim for 100 m!",
	])
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	text.add_theme_font_size_override("font_size", 20)
	g.add_child(text)
	g.add_child(_button("BACK", _show_menu))

	# ---- Leaderboard
	_board = _make_screen()
	var b := _make_card(_board, 460)
	b.add_child(_label("LEADERBOARD", 36, GOLD))
	_board_grid = _make_grid()
	b.add_child(_board_grid)
	b.add_child(_button("BACK", _show_menu))

	# ---- Game over
	_over = _make_screen()
	var o := _make_card(_over, 460)
	o.add_child(_label("GAME OVER", 44, Color(1.0, 0.45, 0.35)))
	_over_summary = _label("", 24)
	o.add_child(_over_summary)
	_over_grid = _make_grid()
	o.add_child(_over_grid)
	o.add_child(_button("PLAY AGAIN", _start_game))
	o.add_child(_button("MAIN MENU", _show_menu))

func _label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _cell(text: String, color: Color, align: HorizontalAlignment, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 54)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", Color(0.06, 0.07, 0.1))
	btn.add_theme_color_override("font_pressed_color", Color(0.06, 0.07, 0.1))
	btn.add_theme_stylebox_override("normal", _btn_style(Color(1, 1, 1, 0.05), Color(GOLD.r, GOLD.g, GOLD.b, 0.45)))
	btn.add_theme_stylebox_override("hover", _btn_style(GOLD, GOLD))
	btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.8, 0.66, 0.32), GOLD))
	btn.add_theme_stylebox_override("focus", _btn_style(Color(1, 1, 1, 0.05), GOLD))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(callback)
	return btn

func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(10)
	return sb

func _make_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 6)
	return g

# Full-screen dark overlay that also blocks clicks to whatever is behind it.
func _make_screen() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	return root

# A rounded dark card in the middle of a screen; returns the box to fill.
func _make_card(screen: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = NAVY
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(34)
	sb.set_border_width_all(1)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 28
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	return box
