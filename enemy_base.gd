extends CharacterBody2D
class_name EnemyBase

@export var wander_speed           := 60.0
@export var wander_circle_distance := 80.0
@export var wander_circle_radius   := 50.0
@export var wander_drift_rate      := 1.8
@export var wander_turn_speed      := 4.0
@export var avoid_distance         := 70.0
@export var avoid_strength         := 200.0

var _wander_angle    := 0.0
var _desired_velocity := Vector2.ZERO
var _pause_remaining := 0.0
var _next_pause_in   := 0.0


func _ready() -> void:
	_wander_angle = randf() * TAU
	_schedule_next_pause()

# call after add_child() to override wander defaults
# only pass the keys you want to change
func init_wander(config: Dictionary = {}) -> void:
	wander_speed           = config.get("speed",           wander_speed)
	wander_circle_distance = config.get("circle_distance", wander_circle_distance)
	wander_circle_radius   = config.get("circle_radius",   wander_circle_radius)
	wander_drift_rate      = config.get("drift_rate",      wander_drift_rate)
	wander_turn_speed      = config.get("turn_speed",      wander_turn_speed)
	avoid_distance         = config.get("avoid_distance",  avoid_distance)
	avoid_strength         = config.get("avoid_strength",  avoid_strength)

func _base_physics(delta: float) -> void:
	_next_pause_in -= delta
	if _next_pause_in <= 0.0:
		_schedule_next_pause()
	if _pause_remaining > 0.0:
		_pause_remaining -= delta
		_desired_velocity = _desired_velocity.lerp(Vector2.ZERO, wander_turn_speed * delta)
		velocity = _desired_velocity
		move_and_slide()
		return
	var steer := _compute_wander_steer(delta)
	steer += _compute_avoidance()
	_desired_velocity = _desired_velocity.lerp(steer, wander_turn_speed * delta)
	velocity = _desired_velocity
	move_and_slide()

func _schedule_next_pause() -> void:
	_next_pause_in = randf_range(3.0, 7.0)
	if randf() < 0.3:
		_pause_remaining = randf_range(0.5, 1.5)

func _compute_wander_steer(delta: float) -> Vector2:
	_wander_angle += randf_range(-wander_drift_rate, wander_drift_rate) * delta
	var forward := velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT.rotated(rotation)
	var circle_center := global_position + forward * wander_circle_distance
	var target := circle_center + Vector2.from_angle(_wander_angle) * wander_circle_radius
	return (target - global_position).normalized() * wander_speed

func _compute_avoidance() -> Vector2:
	var avoidance := Vector2.ZERO
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	params.exclude = [self]
	params.collision_mask = 1
	var forward := velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT.rotated(rotation)
	for dir in [forward.rotated(-0.6), forward, forward.rotated(0.6)]:
		params.from = global_position
		params.to   = global_position + dir * avoid_distance
		var result  := space.intersect_ray(params)
		if result:
			var proximity : float = 1.0 - (result.position.distance_to(global_position) / avoid_distance)
			avoidance += result.normal * avoid_strength * proximity
	return avoidance
