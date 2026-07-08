extends CharacterBody2D

@export var knockback_friction = 600 # how fast the knockback impulse decays

@export_group("Patrol")
@export var patrol_mode: GuardStateComponent.PatrolMode = GuardStateComponent.PatrolMode.LOOP
@export var patrol_path: PathFollow2D
@export var patrol_speed: float = 0.08
@export var patrol_waypoints: Array[Node2D] = []
## Seconds of walking between look-around stops for LOOP/PING_PONG. 0 disables stopping.
@export var path_stop_interval: float = 0.0

@export_group("Look Behavior")
## Angles (degrees, relative to the guard's facing when it starts looking) to turn
## through in order. Include 0.0 last to end up facing the way it started.
@export var look_angles: Array[float] = [-60.0, 60.0, 0.0]
@export var look_pause_duration: float = 0.6
@export var look_hold_duration: float = 0.5
@export var look_turn_speed_degrees: float = 240.0
## LOOP rounds back to look_angles[0] every repeat; PING_PONG alternates direction.
@export var look_cycle_mode: GuardStateComponent.LookCycleMode = GuardStateComponent.LookCycleMode.LOOP

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision: VisionComponent = $Components/Vision
@onready var attack_component: AttackComponent = $Components/AttackComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var hurtbox_component: HurtboxComponent = $Components/HurtboxComponent
@onready var guard_state: GuardStateComponent = $Components/GuardStateComponent

var last_direction = "right"
var facing_direction := Vector2.RIGHT
var knockback_velocity := Vector2.ZERO


func _ready():
	guard_state.patrol_mode = patrol_mode
	guard_state.patrol_path = patrol_path
	guard_state.patrol_speed = patrol_speed
	guard_state.patrol_waypoints = patrol_waypoints
	guard_state.path_stop_interval = path_stop_interval
	guard_state.look_angles = look_angles
	guard_state.look_pause_duration = look_pause_duration
	guard_state.look_hold_duration = look_hold_duration
	guard_state.look_turn_speed_degrees = look_turn_speed_degrees
	guard_state.look_cycle_mode = look_cycle_mode

	vision.target_spotted.connect(_on_vision_target_spotted)
	vision.target_lost.connect(_on_vision_target_lost)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	GlobalAlertState.state_changed.connect(_on_global_alert_state_changed)
	GlobalAlertState.player_position_updated.connect(_on_global_player_position_updated)


func _on_vision_target_spotted(body: Node2D) -> void:
	print("Player spotted!")
	guard_state.set_target(body)
	GlobalAlertState.report_sighting(body.global_position)


func _on_vision_target_lost(body: Node2D) -> void:
	if guard_state.clear_target(body):
		print("Player lost, heading to last known position...")


func _on_global_alert_state_changed(new_state: GlobalAlertState.State) -> void:
	if new_state == GlobalAlertState.State.ALERT:
		guard_state.receive_global_alert(GlobalAlertState.last_known_position)


func _on_global_player_position_updated(player_position: Vector2) -> void:
	guard_state.receive_global_alert(player_position)


func _physics_process(delta):
	guard_state.process_state(delta)

	if guard_state.target:
		GlobalAlertState.report_sighting(guard_state.target.global_position)

	if guard_state.move_direction.length() > 0.1:
		vision.rotation = guard_state.move_direction.angle()
	update_animation(velocity.normalized())

	if knockback_velocity.length() > 1.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO

	move_and_slide()


func apply_knockback(direction: Vector2, force: float) -> void:
	knockback_velocity = direction * force


func _on_damaged(amount: int) -> void:
	print("Guard took ", amount, " damage")


func _on_died() -> void:
	print("Guard down!")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	queue_free()


func update_animation(direction: Vector2):
	var anim = ""
	if direction.length() > 0:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				anim = "move_right"
				last_direction = "right"
				facing_direction = Vector2.RIGHT
			else:
				anim = "move_left"
				last_direction = "left"
				facing_direction = Vector2.LEFT
		else:
			if direction.y > 0:
				anim = "move_down"
				last_direction = "down"
				facing_direction = Vector2.DOWN
			else:
				anim = "move_up"
				last_direction = "up"
				facing_direction = Vector2.UP
	else:
		anim = "idle_" + last_direction

	attack_component.rotation = facing_direction.angle()

	if animated_sprite_2d.animation != anim:
		animated_sprite_2d.play(anim)
