extends CharacterBody2D

enum State { IDLE, ALERT, ATTACK}

@export var speed = 300
@export var friction = 1
@export var acceleration = 1
@export var patrol_path:PathFollow2D = null
@export var patrol_speed = 0.08
@export var knockback_friction = 600 # how fast the knockback impulse decays

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision: Area2D = $Vision
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var attack_component: AttackComponent = $AttackComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var last_direction = "right"
var player = null
var current_state = State.IDLE
var move_direction = Vector2.RIGHT
var facing_direction := Vector2.RIGHT
var patrol_target_set = false
var knockback_velocity := Vector2.ZERO


func _ready():
	vision.body_entered.connect(_on_vision_body_entered)
	vision.body_exited.connect(_on_vision_body_exited)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _on_vision_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player spotted!")
		player = body
		current_state = State.ALERT


func _on_vision_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player lost...")
		player = null
		patrol_target_set = false
		current_state = State.IDLE


func _physics_process(delta):
	match current_state:
		State.IDLE:
			_handle_idle(delta)
		State.ALERT:
			_handle_alert()
		State.ATTACK:
			_handle_attack()
	
	_rotate_vision_cone()
	update_animation(velocity.normalized())

	if knockback_velocity.length() > 1.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO

	move_and_slide()


func apply_knockback(direction: Vector2, force: float) -> void:
	knockback_velocity = direction * force


func _rotate_vision_cone():
	if move_direction.length() > 0.1:
		vision.rotation = move_direction.angle()


func _handle_idle(_delta):
	if patrol_path == null:
		velocity = velocity.lerp(Vector2.ZERO, friction)
		return
	if not patrol_target_set or navigation_agent_2d.is_navigation_finished():
		patrol_path.progress_ratio += patrol_speed
		navigation_agent_2d.target_position = patrol_path.global_position
		patrol_target_set = true
	if not navigation_agent_2d.is_navigation_finished():
		var next_point = navigation_agent_2d.get_next_path_position()
		move_direction = (next_point - global_position).normalized()
		velocity = velocity.lerp(move_direction * speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)

func _handle_alert():
	if player:
		navigation_agent_2d.target_position = player.global_position
	
	if not navigation_agent_2d.is_navigation_finished():
		var next_point = navigation_agent_2d.get_next_path_position()
		move_direction = (next_point - global_position).normalized()
		velocity = velocity.lerp(move_direction * speed, acceleration)
	else:
		current_state = State.ATTACK



func _handle_attack():
	velocity = velocity.lerp(Vector2.ZERO, friction)
	if player == null:
		current_state = State.IDLE


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
	
	if animated_sprite_2d.animation != anim:
		animated_sprite_2d.play(anim)
