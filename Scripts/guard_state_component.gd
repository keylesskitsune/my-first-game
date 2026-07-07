extends Node
class_name GuardStateComponent

enum State { IDLE, ALERT, ATTACK }

@export var body: CharacterBody2D
@export var navigation_agent: NavigationAgent2D
@export var patrol_path: PathFollow2D
@export var patrol_speed: float = 0.08
@export var speed: float = 300
@export var friction: float = 1
@export var acceleration: float = 1

var current_state: State = State.IDLE
var move_direction := Vector2.RIGHT
var target: Node2D = null

var _patrol_target_set := false


func set_target(new_target: Node2D) -> void:
	target = new_target
	current_state = State.ALERT


func clear_target(lost_target: Node2D) -> bool:
	if lost_target != target:
		return false

	target = null
	_patrol_target_set = false
	current_state = State.IDLE
	return true


func process_state() -> void:
	match current_state:
		State.IDLE:
			_handle_idle()
		State.ALERT:
			_handle_alert()
		State.ATTACK:
			_handle_attack()


func _handle_idle() -> void:
	if patrol_path == null:
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		return

	if not _patrol_target_set or navigation_agent.is_navigation_finished():
		patrol_path.progress_ratio += patrol_speed
		navigation_agent.target_position = patrol_path.global_position
		_patrol_target_set = true

	_move_toward_nav_target()


func _handle_alert() -> void:
	if target:
		navigation_agent.target_position = target.global_position

	if not navigation_agent.is_navigation_finished():
		_move_toward_nav_target()
	else:
		current_state = State.ATTACK


func _handle_attack() -> void:
	body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
	if target == null:
		current_state = State.IDLE


func _move_toward_nav_target() -> void:
	if navigation_agent.is_navigation_finished():
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		return

	var next_point := navigation_agent.get_next_path_position()
	move_direction = (next_point - body.global_position).normalized()
	body.velocity = body.velocity.lerp(move_direction * speed, acceleration)
