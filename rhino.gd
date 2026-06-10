extends EnemyBase

enum State { IDLE, WINDUP, CHARGING, STUNNED }

@export var detection_range := 200.0
@export var charge_speed    := 400.0
@export var charge_range    := 300.0
@export var windup_time     := 0.8
@export var stun_time       := 1.2

var state                   := State.IDLE
var player: Node2D          = null
var player_in_radius        := false
var charge_direction        := Vector2.ZERO
var charge_distance_traveled := 0.0

@onready var raycast:        RayCast2D  = $RayCast2D
@onready var windup_timer:   Timer      = $WindupTimer
@onready var stun_timer:     Timer      = $StunTimer
@onready var detection_area: Area2D     = $DetectionArea

func _ready() -> void:
	super()
	windup_timer.one_shot = true
	stun_timer.one_shot   = true
	windup_timer.timeout.connect(_on_windup_timeout)
	stun_timer.timeout.connect(_on_stun_timeout)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	_apply_detection_range()

# call after add_child() to override rhino-specific defaults
func init(config: Dictionary = {}) -> void:
	detection_range = config.get("detection_range", detection_range)
	charge_speed    = config.get("charge_speed",    charge_speed)
	charge_range    = config.get("charge_range",    charge_range)
	windup_time     = config.get("windup_time",     windup_time)
	stun_time       = config.get("stun_time",       stun_time)
	windup_timer.wait_time = windup_time
	stun_timer.wait_time   = stun_time
	_apply_detection_range()

func _apply_detection_range() -> void:
	var shape        := CircleShape2D.new()
	shape.radius      = detection_range
	detection_area.get_node("CollisionShape2D").shape = shape

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_base_physics(delta)
			if player_in_radius and can_see_player():
				set_state(State.WINDUP)
		State.WINDUP:
			velocity = Vector2.ZERO
			move_and_slide()
		State.CHARGING:
			velocity = charge_direction * charge_speed
			move_and_slide()
			if get_slide_collision_count() > 0:
				set_state(State.STUNNED)
				return
			if velocity.length() < charge_speed * 0.5:
				set_state(State.STUNNED)
				return
			charge_distance_traveled += velocity.length() * delta
			if charge_distance_traveled >= charge_range:
				set_state(State.STUNNED)
		State.STUNNED:
			velocity = Vector2.ZERO
			move_and_slide()

func can_see_player() -> bool:
	if player == null:
		return false
	raycast.target_position = player.global_position - global_position
	raycast.force_raycast_update()
	return not raycast.is_colliding() or raycast.get_collider() == player

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_in_radius = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = null
		player_in_radius = false
		if state == State.WINDUP:
			set_state(State.IDLE)

func _on_windup_timeout() -> void:
	if not can_see_player():
		set_state(State.IDLE)
		return
	charge_direction = (player.global_position - global_position).normalized()
	set_state(State.CHARGING)

func _on_stun_timeout() -> void:
	set_state(State.IDLE)

func set_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.WINDUP:
			windup_timer.start()
		State.CHARGING:
			charge_distance_traveled = 0.0
		State.STUNNED:
			velocity = Vector2.ZERO
			stun_timer.start()
