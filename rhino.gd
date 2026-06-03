extends CharacterBody2D

enum State { IDLE, WINDUP, CHARGING, STUNNED }

# --- Settings ---
@export var charge_speed = 400.0
@export var charge_range = 300.0
@export var detection_range = 200.0
@export var windup_time = 0.8
@export var stun_time = 1.2

# --- State ---
var state = State.IDLE
var charge_direction = Vector2.ZERO
var charge_distance_traveled = 0.0
var player = null

@onready var anim = $AnimatedSprite2D
@onready var raycast = $RayCast2D
@onready var windup_timer = $WindupTimer
@onready var stun_timer = $StunTimer
@onready var detection_area = $Area2D
@onready var detection_shape = $Area2D/CollisionShape2D

func _ready():
	# size detection shape from export variable
	var circle = CircleShape2D.new()
	circle.radius = detection_range
	detection_shape.shape = circle

	# connect timer signals
	windup_timer.wait_time = windup_time
	stun_timer.wait_time = stun_time
	windup_timer.timeout.connect(_on_windup_timeout)
	stun_timer.timeout.connect(_on_stun_timeout)

	# connect area signals
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

	print("Rhino ready")
	set_state(State.IDLE)

func _physics_process(delta):
	match state:
		State.IDLE:
			velocity = Vector2.ZERO

		State.WINDUP:
			velocity = Vector2.ZERO

		State.CHARGING:
			velocity = charge_direction * charge_speed
			move_and_slide()
			charge_distance_traveled += charge_speed * delta
			if get_slide_collision_count() > 0:
				set_state(State.STUNNED)
				return
			if charge_distance_traveled >= charge_range:
				set_state(State.STUNNED)
			return

		State.STUNNED:
			velocity = Vector2.ZERO
			return

	move_and_slide()

# --- Timer callbacks ---
func _on_windup_timeout():
	if player != null:
		charge_direction = (player.global_position - global_position).normalized()
	set_state(State.CHARGING)

func _on_stun_timeout():
	set_state(State.IDLE)

# --- Detection callbacks ---
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Player detected")
		player = body
		if state == State.IDLE:
			set_state(State.WINDUP)

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Player left detection range")
		player = null

# --- Central state manager ---
func set_state(new_state: State):
	state = new_state

	match new_state:
		State.IDLE:
			print("Rhino: IDLE")
			anim.play("idle")

		State.WINDUP:
			print("Rhino: WINDUP")
			windup_timer.wait_time = windup_time
			windup_timer.start()
			anim.play("windup")

		State.CHARGING:
			print("Rhino: CHARGING")
			charge_distance_traveled = 0.0
			anim.play("charging")

		State.STUNNED:
			print("Rhino: STUNNED")
			velocity = Vector2.ZERO
			stun_timer.wait_time = stun_time
			stun_timer.start()
			anim.play("stunned")

# --- Debug Drawing ---
const DEBUG = true

func _process(_delta):
	if DEBUG:
		queue_redraw()

func _draw():
	if not DEBUG:
		return
	draw_arc(Vector2.ZERO, detection_range, 0, TAU, 64, Color.YELLOW, 2.0)
	if state == State.WINDUP:
		if player != null:
			var dir = (player.global_position - global_position).normalized()
			draw_dashed_line(Vector2.ZERO, dir * charge_range, Color.ORANGE, 2.0)
	if state == State.CHARGING:
		var remaining = charge_range - charge_distance_traveled
		draw_line(Vector2.ZERO, charge_direction * remaining, Color.RED, 3.0)
	var state_colors = {
		State.IDLE: Color.GRAY,
		State.WINDUP: Color.ORANGE,
		State.CHARGING: Color.RED,
		State.STUNNED: Color.BLUE
	}
	draw_arc(Vector2.ZERO, 6.0, 0, TAU, 16, state_colors[state], 3.0)
