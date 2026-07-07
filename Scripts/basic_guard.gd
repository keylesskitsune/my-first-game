extends CharacterBody2D

@export var knockback_friction = 600 # how fast the knockback impulse decays

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
	vision.target_spotted.connect(_on_vision_target_spotted)
	vision.target_lost.connect(_on_vision_target_lost)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)


func _on_vision_target_spotted(body: Node2D) -> void:
	print("Player spotted!")
	guard_state.set_target(body)


func _on_vision_target_lost(body: Node2D) -> void:
	if guard_state.clear_target(body):
		print("Player lost...")


func _physics_process(delta):
	guard_state.process_state()

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
