extends CharacterBody2D

@export var speed = 300
@export var friction = 1
@export var acceleration = 1

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_component: AttackComponent = $AttackComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var last_direction = "down"


func get_input():
	var input = Vector2()
	if Input.is_action_pressed('right'):
		input.x += 1
	if Input.is_action_pressed('left'):
		input.x -= 1
	if Input.is_action_pressed('down'):
		input.y += 1
	if Input.is_action_pressed('up'):
		input.y -= 1
	return input

func _input(event):
	if event.is_action_pressed("attack"):
		attack_component.attack()

func update_animation(direction: Vector2):
	var anim = ""
	if direction.length() > 0:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				anim = "move_right"
				last_direction = "right"  # 👈 remember it
			else:
				anim = "move_left"
				last_direction = "left"
		else:
			if direction.y > 0:
				anim = "move_down"
				last_direction = "down"
			else:
				anim = "move_up"
				last_direction = "up"
	else:
		anim = "idle_" + last_direction
	
	if animated_sprite_2d.animation != anim:
		animated_sprite_2d.play(anim)


func _physics_process(_delta):
	var direction = get_input()
	if direction.length() > 0:
		velocity = velocity.lerp(direction.normalized() * speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
	update_animation(direction)
	move_and_slide()


func _on_health_changed(current: int, max: int) -> void:
	print("Player health: ", current, "/", max)

func _on_died() -> void:
	print("Player caught!")
