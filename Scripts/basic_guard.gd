extends CharacterBody2D

@export var speed = 300
@export var friction = 1
@export var acceleration = 1

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var last_direction = "down"

func update_animation(direction: Vector2):
	var anim = ""
	if direction.length() > 0:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				anim = "move_right"
				last_direction = "right"
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
	var direction = Vector2.ZERO
	if direction.length() > 0:
		velocity = velocity.lerp(direction.normalized() * speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
	update_animation(direction)
	move_and_slide()
