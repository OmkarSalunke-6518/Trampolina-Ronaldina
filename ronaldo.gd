extends CharacterBody2D

signal jumped(tier: int)
signal landed(peak_m: float)   # peak_m = highest point of the jump that just ended

@export var gravity: float = 1200.0
## How many pixels equal 1 metre. Tier 10 = 100 m = 4000 px.
@export var pixels_per_meter: float = 40.0

var is_airborne: bool = false
var input_enabled: bool = false    # GameManager switches this on/off
var ground_y: float = 0.0          # Y position while standing on the trampoline
var peak_m: float = 0.0            # highest point of the current jump
var _input_lock: float = 0.0       # short delay so the Play click can't also be a jump

@onready var indicator = get_node("../CanvasLayer/TimingBarUI/BarGraphic/Indicator")

func _ready() -> void:
	ground_y = global_position.y

func enable_input(delay: float = 0.3) -> void:
	input_enabled = true
	_input_lock = delay

func disable_input() -> void:
	input_enabled = false

func _physics_process(delta: float) -> void:
	_input_lock = maxf(0.0, _input_lock - delta)

	if not is_on_floor():
		velocity.y += gravity * delta
		if is_airborne:
			peak_m = maxf(peak_m, get_height_m())
	else:
		ground_y = global_position.y   # remember where the floor is

		if is_airborne:
			is_airborne = false
			velocity.y = 0.0
			landed.emit(peak_m)        # GameManager reacts right away (disables input)

		if input_enabled and _input_lock <= 0.0 and Input.is_action_just_pressed("ui_accept") and indicator:
			var tier: int = indicator.get_tier()   # 10 = green center
			indicator.set_process(false)           # freeze the bar where you pressed
			trigger_jump(tier)

	move_and_slide()

func trigger_jump(height_tier: int) -> void:
	var target_height_pixels = (height_tier * 10.0) * pixels_per_meter
	velocity.y = -sqrt(2.0 * gravity * target_height_pixels)
	is_airborne = true
	peak_m = 0.0
	jumped.emit(height_tier)

# Current height above the trampoline, in metres (never below 0).
func get_height_m() -> float:
	return maxf(0.0, (ground_y - global_position.y) / pixels_per_meter)
