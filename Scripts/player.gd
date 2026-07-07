extends CharacterBody2D

@export var walk_speed = 300
@export var run_speed = 500
@export var friction = 1
@export var acceleration = 1

@export var wall_slide_speed: float = 150
@export var wall_slide_collision_scale: float = 0.6
@export var wall_slide_press_threshold: float = 0.9

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_component: AttackComponent = $AttackComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

enum State { NORMAL, WALL_SLIDE }

var state: State = State.NORMAL
var wall_slide_direction := Vector2.ZERO
var default_collision_size: Vector2

var last_direction = "down"
var facing_direction := Vector2.DOWN
var is_running := false

func _ready():
	default_collision_size = collision_shape.shape.size

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
	if event.is_action_pressed("attack"):
		if state == State.WALL_SLIDE:
			return
		attack_component.attack()
		print("swing")

func _direction_to_string(dir: Vector2) -> String:
	if dir == Vector2.UP:
		return "up"
	elif dir == Vector2.DOWN:
		return "down"
	elif dir == Vector2.LEFT:
		return "left"
	elif dir == Vector2.RIGHT:
		return "right"
	return last_direction

func _snap_to_cardinal(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		return Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if dir.y > 0 else Vector2.UP

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


func update_wall_slide_animation():
	var anim = "slide_left"
	animated_sprite_2d.flip_h = false
	if wall_slide_direction == Vector2.UP:
		anim = "slide_up"
	elif wall_slide_direction == Vector2.DOWN:
		anim = "slide_down"
	elif wall_slide_direction == Vector2.LEFT:
		anim = "slide_left"
	elif wall_slide_direction == Vector2.RIGHT:
		anim = "slide_left"
		animated_sprite_2d.flip_h = true

	attack_component.rotation = facing_direction.angle()

	if animated_sprite_2d.animation != anim:
		animated_sprite_2d.play(anim)


func _is_holding_into_wall() -> bool:
	if wall_slide_direction == Vector2.UP:
		return Input.is_action_pressed('up')
	elif wall_slide_direction == Vector2.DOWN:
		return Input.is_action_pressed('down')
	elif wall_slide_direction == Vector2.LEFT:
		return Input.is_action_pressed('left')
	elif wall_slide_direction == Vector2.RIGHT:
		return Input.is_action_pressed('right')
	return false


func _enter_wall_slide(wall_dir: Vector2):
	state = State.WALL_SLIDE
	wall_slide_direction = _snap_to_cardinal(wall_dir)
	facing_direction = wall_slide_direction
	last_direction = _direction_to_string(wall_slide_direction)
	velocity = Vector2.ZERO
	collision_shape.shape.size = default_collision_size * wall_slide_collision_scale
	update_wall_slide_animation()


func _exit_wall_slide():
	state = State.NORMAL
	wall_slide_direction = Vector2.ZERO
	collision_shape.shape.size = default_collision_size


func _check_wall_slide_enter(direction: Vector2):
	if direction.length() == 0:
		return
	var input_dir = direction.normalized()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if input_dir.dot(-normal) >= wall_slide_press_threshold:
			_enter_wall_slide(-normal)
			return


func _process_normal_movement(direction: Vector2):
	var target_speed = run_speed if is_running else walk_speed
	if direction.length() > 0:
		velocity = velocity.lerp(direction.normalized() * target_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
	update_animation(direction)
	move_and_slide()
	_check_wall_slide_enter(direction)


func _process_wall_slide(_direction: Vector2):
	if not _is_holding_into_wall():
		_exit_wall_slide()
		return

	var tangent = Vector2.ZERO
	if wall_slide_direction.x != 0:
		if Input.is_action_pressed('up'):
			tangent.y -= 1
		if Input.is_action_pressed('down'):
			tangent.y += 1
	else:
		if Input.is_action_pressed('left'):
			tangent.x -= 1
		if Input.is_action_pressed('right'):
			tangent.x += 1

	if tangent.length() > 0:
		velocity = velocity.lerp(tangent.normalized() * wall_slide_speed, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)

	update_wall_slide_animation()
	move_and_slide()

	if get_slide_collision_count() == 0:
		_exit_wall_slide()


func _physics_process(_delta):
	var direction = get_input()
	match state:
		State.NORMAL:
			_process_normal_movement(direction)
		State.WALL_SLIDE:
			_process_wall_slide(direction)


func _on_health_changed(current: int, max_hp: int) -> void:
	print("Player health: ", current, "/", max_hp)

func _on_died() -> void:
	print("Player caught!")
