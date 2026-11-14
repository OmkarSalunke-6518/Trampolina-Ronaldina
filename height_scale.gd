extends Control

## Wall-growth-chart style height ruler on the right side of the screen.
## Drawn entirely in code, so it needs no images.

@export var max_meters: float = 100.0   # top of the ruler (tier 10 reaches ~99 m)
@export var tick_every: float = 10.0    # a number every 10 m

const HEADER := 34.0
const FOOTER := 40.0
const TRACK_X := 70.0
const TRACK_W := 14.0

var height_m: float = 0.0
var best_m: float = 0.0
var flags: Array = []                   # milestone heights, filled from MilestoneManager

@onready var player = get_node("../../Ronaldo")

func _ready() -> void:
	var mm = get_node_or_null("../MilestoneManager")
	if mm:
		for m in mm.milestones:
			flags.append(float(m["meters"]))

func _process(_delta: float) -> void:
	var h: float = player.get_height_m()
	if not is_equal_approx(h, height_m):
		height_m = h
		best_m = maxf(best_m, h)
		queue_redraw()

func _y_for(meters: float) -> float:
	var top := HEADER
	var bottom := size.y - FOOTER
	return lerpf(bottom, top, clampf(meters / max_meters, 0.0, 1.0))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var top := _y_for(max_meters)
	var bottom := _y_for(0.0)
	var cur := _y_for(height_m)

	# panel + title
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.11, 0.7))
	draw_string(font, Vector2(0, 23), "HEIGHT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)

	# track + filled part up to Ronaldo
	draw_rect(Rect2(TRACK_X, top, TRACK_W, bottom - top), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(TRACK_X, cur, TRACK_W, bottom - cur), Color(0.93, 0.78, 0.40, 0.95))

	# ruler ticks and numbers
	var step := maxf(tick_every, 1.0)
	var m := 0.0
	while m <= max_meters + 0.001:
		var y := _y_for(m)
		draw_line(Vector2(TRACK_X - 8, y), Vector2(TRACK_X + TRACK_W, y), Color.WHITE, 2.0)
		draw_string(font, Vector2(0, y + 5), "%d" % int(m), HORIZONTAL_ALIGNMENT_RIGHT, TRACK_X - 14, 14, Color.WHITE)
		m += step

	# milestone flags (gold arrows on the right of the track)
	for f in flags:
		if f <= 0.5:
			continue            # the 0 m zone starts on the ground, no arrow
		var fy := _y_for(f)
		var fx := TRACK_X + TRACK_W + 4
		draw_colored_polygon(
			PackedVector2Array([Vector2(fx + 14, fy - 6), Vector2(fx + 14, fy + 6), Vector2(fx, fy)]),
			Color(0.93, 0.78, 0.40))

	# best height so far
	if best_m > 0.5:
		var by := _y_for(best_m)
		draw_line(Vector2(TRACK_X - 4, by), Vector2(TRACK_X + TRACK_W + 4, by), Color(1.0, 0.5, 0.1), 2.0)

	# Ronaldo marker
	var mx := TRACK_X + TRACK_W / 2.0
	draw_circle(Vector2(mx, cur), 9.0, Color.WHITE)
	draw_circle(Vector2(mx, cur), 6.0, Color(0.93, 0.78, 0.40))

	# current height readout
	draw_string(font, Vector2(0, size.y - 12), "%d m" % int(height_m), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color.WHITE)
