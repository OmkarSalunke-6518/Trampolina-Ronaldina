extends Control

## Meme player. When Ronaldo LANDS, the game calls play_for_peak() with the highest
## point of that jump. The matching meme sound plays, its picture + caption pop up,
## and both end together (the picture stays exactly as long as the sound lasts).
##
## Each entry is a ZONE that starts at "meters":
##   0-20 m  -> Tuco "get out"      20-40 m -> perfect fart     40-60 m -> movie one
##   60-80 m -> galaxy meme         80-95 m -> tiki tiki        100 m -> GTA mission passed
## Sounds live in res://audio/ and pictures in res://memes/.
## For "image" write the path WITHOUT the extension: .png .jpg .jpeg .webp are found
## automatically. If a file is missing it is skipped (the caption still shows).

var milestones: Array = [
	{"meters": 0.0,  "sound": "res://audio/get_out.mp3",      "image": "res://memes/get_out",      "text": "GET OUT!"},
	{"meters": 20.0, "sound": "res://audio/perfect_fart.mp3", "image": "res://memes/perfect_fart", "text": "PERFECT."},
	{"meters": 40.0, "sound": "res://audio/movie_1.mp3",      "image": "res://memes/movie_1",      "text": "MOVIE TIME"},
	{"meters": 60.0, "sound": "res://audio/galaxy_meme.mp3",  "image": "res://memes/galaxy_meme",  "text": "GALAXY BRAIN"},
	{"meters": 80.0, "sound": "res://audio/tiki_tiki.mp3",    "image": "res://memes/tiki_tiki",    "text": "TIKI TIKI!"},
	# A perfect (green zone) jump peaks at ~100 m, so 95 m+ counts as the 100 m jump.
	{"meters": 95.0, "sound": "res://audio/gta_mission_passed.mp3", "image": "res://memes/gta_mission_passed", "text": "MISSION PASSED!"},
]

@export var popup_size: float = 320.0
## Used only when a sound file is missing: how long the picture/caption stays.
@export var fallback_seconds: float = 2.0

var _holder: Control
var _image: TextureRect
var _caption: Label
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_popup()

# Plays the meme for the zone that peak_m falls in and returns when it is over.
func play_for_peak(peak_m: float) -> void:
	var m: Dictionary = _pick(peak_m)

	# picture + caption
	var img: String = _find_image(m.get("image", ""))
	var has_image := false
	if img != "":
		_image.texture = load(img) as Texture2D
		has_image = _image.texture != null
	_caption.text = m.get("text", "")
	_show_popup(has_image)

	# sound (the picture stays exactly as long as the sound)
	var wait := fallback_seconds
	var snd: String = m.get("sound", "")
	if snd != "":
		var stream: AudioStream = null
		if ResourceLoader.exists(snd):
			stream = load(snd) as AudioStream
		if stream:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			p.finished.connect(p.queue_free)
			p.play()
			wait = maxf(stream.get_length(), 0.5)
		else:
			push_warning("Meme sound not found: " + snd)

	await get_tree().create_timer(wait).timeout
	_hide_popup()

func _pick(peak_m: float) -> Dictionary:
	var chosen: Dictionary = milestones[0]
	for m in milestones:
		if peak_m >= float(m["meters"]):
			chosen = m
	return chosen

# Accepts "res://memes/name" (any extension) or a full path with extension.
# Returns "" if no picture exists yet.
func _find_image(base: String) -> String:
	if base == "":
		return ""
	if ResourceLoader.exists(base):
		return base
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var path: String = base + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""

func _build_popup() -> void:
	var total_h := popup_size + 60.0

	# holder sits on the left-middle of the screen (Ronaldo is in the middle)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchor_and_offset(SIDE_LEFT, 0.0, 30.0)
	_holder.set_anchor_and_offset(SIDE_RIGHT, 0.0, 30.0 + popup_size)
	_holder.set_anchor_and_offset(SIDE_TOP, 0.5, -total_h / 2.0)
	_holder.set_anchor_and_offset(SIDE_BOTTOM, 0.5, total_h / 2.0)
	_holder.pivot_offset = Vector2(popup_size / 2.0, total_h / 2.0)
	_holder.modulate.a = 0.0
	add_child(_holder)

	_image = TextureRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.position = Vector2.ZERO
	_image.size = Vector2(popup_size, popup_size)
	_holder.add_child(_image)

	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.size = Vector2(popup_size, 60)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(0.93, 0.78, 0.40))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("outline_size", 8)
	_holder.add_child(_caption)

func _show_popup(has_image: bool) -> void:
	if _tween:
		_tween.kill()

	_image.visible = has_image
	_caption.visible = _caption.text != ""
	# no image -> centre the caption instead of leaving a gap above it
	_caption.position = Vector2(0, popup_size if has_image else popup_size / 2.0 - 30.0)

	_holder.scale = Vector2(0.6, 0.6)
	_holder.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(_holder, "modulate:a", 1.0, 0.15)
	_tween.parallel().tween_property(_holder, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_popup() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_holder, "modulate:a", 0.0, 0.15)
