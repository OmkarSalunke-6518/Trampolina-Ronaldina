extends ColorRect

## Moves back and forth across the timing bar with an UNPREDICTABLE speed.
## The speed keeps drifting to new random targets (fast, slow, sudden bursts)
## and sometimes the indicator even flips direction in the middle of the bar.
## The random rules are identical on every try, so every round is equally hard.

## Size of the green "10" zone as a fraction of HALF the bar.
@export_range(0.02, 0.6) var green_zone: float = 0.2

## Speed range in pixels per second (same for every round = fair difficulty).
const MIN_SPEED := 130.0
const MAX_SPEED := 850.0
## How often a new target speed is picked (seconds).
const RETARGET_MIN := 0.12
const RETARGET_MAX := 0.65
## How quickly the real speed chases the target (higher = snappier changes).
const ACCEL := 7.0
## Chance (per retarget) that the indicator suddenly turns around mid-bar.
const FLIP_CHANCE := 0.18

var direction: int = 1
var min_x: float = 0.0
var max_x: float = 300.0   # set automatically from the bar width

var _speed: float = 300.0
var _target_speed: float = 300.0
var _retarget_in: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_update_range()
	_pick_new_target()

func _process(delta: float) -> void:
	_update_range()

	_retarget_in -= delta
	if _retarget_in <= 0.0:
		_pick_new_target()

	_speed = lerpf(_speed, _target_speed, clampf(ACCEL * delta, 0.0, 1.0))
	position.x += _speed * direction * delta

	if position.x >= max_x:
		position.x = max_x
		direction = -1
	elif position.x <= min_x:
		position.x = min_x
		direction = 1

# Called by the GameManager at the start of every try so each round begins fresh.
func reset_round() -> void:
	position.x = _rng.randf_range(min_x, max_x)
	direction = 1 if _rng.randf() < 0.5 else -1
	_speed = _rng.randf_range(MIN_SPEED, MAX_SPEED)
	_pick_new_target()

func _pick_new_target() -> void:
	# Mix of slow crawls, medium cruising and fast bursts.
	var roll := _rng.randf()
	if roll < 0.25:
		_target_speed = _rng.randf_range(MIN_SPEED, 260.0)      # crawl
	elif roll < 0.70:
		_target_speed = _rng.randf_range(260.0, 560.0)          # cruise
	else:
		_target_speed = _rng.randf_range(560.0, MAX_SPEED)      # burst
	_retarget_in = _rng.randf_range(RETARGET_MIN, RETARGET_MAX)
	if _rng.randf() < FLIP_CHANCE:
		direction *= -1

# The indicator travels exactly across the BarGraphic, whatever size you give it.
func _update_range() -> void:
	var bar := get_parent() as Control
	if bar:
		max_x = maxf(1.0, bar.size.x - size.x)

# Returns 10 in the green center, dropping to 1 at the far edges.
func get_tier() -> int:
	var center := (min_x + max_x) / 2.0
	var half := (max_x - min_x) / 2.0
	var d := clampf(absf(position.x - center) / half, 0.0, 1.0)   # 0 = middle, 1 = edge
	if d <= green_zone:
		return 10
	var t := (d - green_zone) / (1.0 - green_zone)                # 0..1 outside the green
	return clampi(9 - int(t * 9.0), 1, 9)
