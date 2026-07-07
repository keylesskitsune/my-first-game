extends Node
class_name WallSlideComponent

signal entered(direction: Vector2)
signal exited

@export var body: CharacterBody2D
@export var animated_sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var up_collision_shape: CollisionShape2D
@export var down_collision_shape: CollisionShape2D
@export var left_right_collision_shape: CollisionShape2D

@export var speed: float = 150
@export var press_threshold: float = 0.9

var active: bool = false
var direction := Vector2.ZERO

func _ready() -> void:
	collision_shape.disabled = false
	up_collision_shape.disabled = true
	down_collision_shape.disabled = true
	left_right_collision_shape.disabled = true


func try_enter(input_direction: Vector2) -> bool:
	if input_direction.length() == 0:
		return false

	var normalized_input := input_direction.normalized()
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var normal := collision.get_normal()
		if normalized_input.dot(-normal) >= press_threshold:
			_enter(-normal)
			return true
	return false


func process_slide(acceleration: float, friction: float) -> void:
	if not _is_holding_into_wall() or not _is_wall_still_present():
		_exit()
		return

	var tangent := _tangent_input()
	if tangent.length() > 0:
		body.velocity = body.velocity.lerp(tangent.normalized() * speed, acceleration)
	else:
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)

	_update_animation(tangent.length() > 0)
	body.move_and_slide()


func _enter(wall_normal: Vector2) -> void:
	active = true
	direction = _snap_to_cardinal(wall_normal)
	body.velocity = Vector2.ZERO
	_use_collision_shape_for_direction()
	_update_animation(false)
	entered.emit(direction)


func _exit() -> void:
	active = false
	direction = Vector2.ZERO
	collision_shape.disabled = false
	up_collision_shape.disabled = true
	down_collision_shape.disabled = true
	left_right_collision_shape.disabled = true
	exited.emit()


func _use_collision_shape_for_direction() -> void:
	collision_shape.disabled = true
	# Shapes are named for the animation they pair with (slide_up/slide_down),
	# which is the opposite of the wall direction: pressing UP plays slide_down
	# and needs the "Down" shape's reach; pressing DOWN plays slide_up.
	up_collision_shape.disabled = direction != Vector2.DOWN
	down_collision_shape.disabled = direction != Vector2.UP
	left_right_collision_shape.disabled = direction != Vector2.LEFT and direction != Vector2.RIGHT


func _tangent_input() -> Vector2:
	var tangent := Vector2.ZERO
	if direction.x != 0:
		if Input.is_action_pressed('up'):
			tangent.y -= 1
		if Input.is_action_pressed('down'):
			tangent.y += 1
	else:
		if Input.is_action_pressed('left'):
			tangent.x -= 1
		if Input.is_action_pressed('right'):
			tangent.x += 1
	return tangent


func _is_holding_into_wall() -> bool:
	match direction:
		Vector2.UP:
			return Input.is_action_pressed('up')
		Vector2.DOWN:
			return Input.is_action_pressed('down')
		Vector2.LEFT:
			return Input.is_action_pressed('left')
		Vector2.RIGHT:
			return Input.is_action_pressed('right')
	return false


func _is_wall_still_present() -> bool:
	# The active wall-slide shape is intentionally smaller than the main
	# collision shape (so guards have a harder time spotting a hidden
	# player), which leaves a real local-space gap to the wall. Probe using
	# the main shape's own half-extent so the check reaches the wall
	# regardless of which shape is currently enabled, and transform through
	# the body's full transform so it also accounts for the body's scale.
	var probe_distance := 2.0
	if collision_shape.shape is RectangleShape2D:
		var extents: Vector2 = (collision_shape.shape as RectangleShape2D).size / 2.0
		probe_distance = (extents.x if direction.x != 0 else extents.y) + 2.0

	var params := PhysicsTestMotionParameters2D.new()
	params.from = body.global_transform
	params.motion = body.global_transform.basis_xform(direction * probe_distance)
	var result := PhysicsTestMotionResult2D.new()
	return PhysicsServer2D.body_test_motion(body.get_rid(), params, result)


func _snap_to_cardinal(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		return Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	return Vector2.DOWN if dir.y > 0 else Vector2.UP


func _update_animation(is_moving: bool) -> void:
	var anim_base := "slide_left"
	animated_sprite.flip_h = false
	match direction:
		Vector2.UP:
			anim_base = "slide_down"
		Vector2.DOWN:
			anim_base = "slide_up"
		Vector2.LEFT:
			anim_base = "slide_left"
			animated_sprite.flip_h = true
		Vector2.RIGHT:
			anim_base = "slide_left"

	var anim := anim_base + ("_move" if is_moving else "_idle")
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
