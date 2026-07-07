extends CharacterBody2D

@export var walk_speed = 300
@export var run_speed = 500
@export var friction = 1
@export var acceleration = 1

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_component: AttackComponent = $Components/AttackComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var hurtbox_component: HurtboxComponent = $Components/HurtboxComponent
@onready var wall_slide: WallSlideComponent = $Components/WallSlideComponent

var last_direction = "down"
var facing_direction := Vector2.DOWN
var is_running := false

func _ready():
	wall_slide.entered.connect(_on_wall_slide_entered)

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

	is_running = Input.is_action_pressed('run')
	return input

func _input(event):
	if event.is_action_pressed("attack") and not wall_slide.active:
		attack_component.attack()
		print("swing")

func _direction_to_string(dir: Vector2) -> String:
	match dir:
		Vector2.UP:
			return "up"
		Vector2.DOWN:
			return "down"
		Vector2.LEFT:
			return "left"
		Vector2.RIGHT:
			return "right"
	return last_direction

func update_animation(direction: Vector2):
	var anim = ""
	animated_sprite_2d.flip_h = false
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


func _on_wall_slide_entered(direction: Vector2) -> void:
	facing_direction = direction
	last_direction = _direction_to_string(direction)
	attack_component.rotation = facing_direction.angle()


func _process_normal_movement(direction: Vector2):
	var target_speed = run_speed if is_running else walk_speed
	if direction.length() > 0:
		velocity = velocity.lerp(direction.normalized() * target_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
	update_animation(direction)
	move_and_slide()
	wall_slide.try_enter(direction)


func _physics_process(_delta):
	var direction = get_input()
	if wall_slide.active:
		wall_slide.process_slide(acceleration, friction)
	else:
		_process_normal_movement(direction)


func _on_health_changed(current: int, max_hp: int) -> void:
	print("Player health: ", current, "/", max_hp)

func _on_died() -> void:
	print("Player caught!")
