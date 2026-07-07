extends CharacterBody2D

@export var knockback_friction = 600 # how fast the knockback impulse decays

@export_group("Patrol")
@export var patrol_mode: GuardStateComponent.PatrolMode = GuardStateComponent.PatrolMode.LOOP
@export var patrol_path: PathFollow2D
@export var patrol_speed: float = 0.08
@export var patrol_waypoints: Array[Node2D] = []

@export_group("Look Behavior")
@export var look_pause_duration: float = 0.6
@export var look_side_duration: float = 0.5
@export var look_angle_degrees: float = 60.0

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
	guard_state.look_pause_duration = look_pause_duration
	guard_state.look_side_duration = look_side_duration
	guard_state.look_angle_degrees = look_angle_degrees

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


func _on_global_player_position_updated(position: Vector2) -> void:
	guard_state.receive_global_alert(position)


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
