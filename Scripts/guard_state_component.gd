extends Node
class_name GuardStateComponent

enum State { IDLE, ALERT, ATTACK, SEARCHING, LOOKING }
enum LookPhase { PAUSE_BEFORE, LOOK_LEFT, LOOK_RIGHT, PAUSE_AFTER }

# LOOP: walk patrol_path on a continuous loop (requires the path's curve to
#       form a closed shape, or PathFollow2D.loop = true).
# PING_PONG: walk patrol_path and reverse direction at each end.
# WAYPOINTS: step between patrol_waypoints in order, pausing to look around
#       (reusing the LOOKING state) at each stop before moving on.
# STATIONARY: never move; repeat the pause/look-left/look-right/pause cycle
#       forever on the spot.
enum PatrolMode { LOOP, PING_PONG, WAYPOINTS, STATIONARY }

@export var body: CharacterBody2D
@export var navigation_agent: NavigationAgent2D
@export var speed: float = 300
@export var friction: float = 1
@export var acceleration: float = 1

# Patrol/look-behavior settings are plain vars, not @export: BasicGuard
# exports and forwards them here in _ready() so they show up on the guard's
# root node in the Inspector instead of requiring you to drill into this
# child node.
var patrol_mode: PatrolMode = PatrolMode.LOOP
var patrol_path: PathFollow2D
var patrol_speed: float = 0.08
var patrol_waypoints: Array[Node2D] = []

var look_pause_duration: float = 0.6
var look_side_duration: float = 0.5
var look_angle_degrees: float = 60.0

var current_state: State = State.IDLE
var move_direction := Vector2.RIGHT
var target: Node2D = null
var last_known_position: Vector2

var _patrol_target_set := false
var _patrol_direction := 1
var _waypoint_index := 0
var _look_phase: LookPhase = LookPhase.PAUSE_BEFORE
var _look_timer: float = 0.0
var _look_base_direction := Vector2.RIGHT
var _stationary_look_started := false


func set_target(new_target: Node2D) -> void:
	target = new_target
	current_state = State.ALERT


# Called when the game-wide alert reports a (possibly updated) player
# position from another guard. Guards that already have direct eyes on the
# target (ALERT/ATTACK) trust their own vision over the secondhand report.
func receive_global_alert(position: Vector2) -> void:
	if current_state == State.ALERT or current_state == State.ATTACK:
		return

	last_known_position = position
	_patrol_target_set = false
	_start_searching()


func clear_target(lost_target: Node2D) -> bool:
	if lost_target != target:
		return false

	last_known_position = target.global_position
	target = null
	_patrol_target_set = false
	_start_searching()
	return true


func process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_handle_idle(delta)
		State.ALERT:
			_handle_alert()
		State.ATTACK:
			_handle_attack()
		State.SEARCHING:
			_handle_searching()
		State.LOOKING:
			_handle_looking(delta)


func _handle_idle(delta: float) -> void:
	match patrol_mode:
		PatrolMode.WAYPOINTS:
			_handle_patrol_waypoints()
		PatrolMode.STATIONARY:
			_handle_patrol_stationary(delta)
		_:
			_handle_patrol_path(delta)


func _handle_patrol_path(delta: float) -> void:
	if patrol_path == null:
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		return

	# Creep the bait point forward every frame (scaled by delta) rather than
	# jumping a fixed chunk only when the guard arrives, so patrol_speed is an
	# actual rate (fraction of the path per second) instead of a step size
	# whose visible pace was really dictated by `speed`.
	_advance_patrol_path(delta)

	# Walk straight toward the bait point instead of routing through
	# NavigationAgent2D: the patrol curve is already a walkable, authored
	# route, and re-pathing the nav agent every frame against a target that
	# only creeps a fraction of a pixel caused its corridor calculation to
	# flicker, which showed up as stuttery movement/animation.
	_move_toward_point(patrol_path.global_position, delta)


func _advance_patrol_path(delta: float) -> void:
	if patrol_mode == PatrolMode.PING_PONG:
		# Ping-ponging needs the path to stop at its ends rather than wrapping,
		# since we reverse direction ourselves once progress_ratio hits 0 or 1.
		patrol_path.loop = false
		patrol_path.progress_ratio += patrol_speed * _patrol_direction * delta
		if patrol_path.progress_ratio >= 1.0:
			patrol_path.progress_ratio = 1.0
			_patrol_direction = -1
		elif patrol_path.progress_ratio <= 0.0:
			patrol_path.progress_ratio = 0.0
			_patrol_direction = 1
	else:
		patrol_path.progress_ratio += patrol_speed * delta


func _handle_patrol_waypoints() -> void:
	if patrol_waypoints.is_empty():
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		return

	if not _patrol_target_set:
		navigation_agent.target_position = patrol_waypoints[_waypoint_index].global_position
		_patrol_target_set = true
		_move_toward_nav_target()
		return

	if navigation_agent.is_navigation_finished():
		_waypoint_index = (_waypoint_index + 1) % patrol_waypoints.size()
		_patrol_target_set = false
		_start_looking()
	else:
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


func _handle_searching() -> void:
	navigation_agent.target_position = last_known_position

	if not navigation_agent.is_navigation_finished():
		_move_toward_nav_target()
	else:
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		_start_looking()


func _handle_looking(delta: float) -> void:
	body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
	if _advance_look_cycle(delta):
		current_state = State.IDLE


# STATIONARY patrol never moves; it just repeats the same pause/look-left/
# look-right/pause cycle used by LOOKING forever instead of resolving back
# to IDLE after one pass.
func _handle_patrol_stationary(delta: float) -> void:
	body.velocity = body.velocity.lerp(Vector2.ZERO, friction)

	if not _stationary_look_started:
		_stationary_look_started = true
		_look_base_direction = move_direction if move_direction.length() > 0.1 else Vector2.RIGHT
		_look_phase = LookPhase.PAUSE_BEFORE
		_look_timer = look_pause_duration

	if _advance_look_cycle(delta):
		_look_phase = LookPhase.PAUSE_BEFORE
		_look_timer = look_pause_duration


# Advances the shared pause/look-left/look-right/pause cycle by delta.
# Returns true once PAUSE_AFTER has elapsed, i.e. a full cycle completed.
func _advance_look_cycle(delta: float) -> bool:
	_look_timer -= delta
	if _look_timer > 0.0:
		return false

	match _look_phase:
		LookPhase.PAUSE_BEFORE:
			_look_phase = LookPhase.LOOK_LEFT
			move_direction = _look_base_direction.rotated(-deg_to_rad(look_angle_degrees))
			_look_timer = look_side_duration
		LookPhase.LOOK_LEFT:
			_look_phase = LookPhase.LOOK_RIGHT
			move_direction = _look_base_direction.rotated(deg_to_rad(look_angle_degrees))
			_look_timer = look_side_duration
		LookPhase.LOOK_RIGHT:
			_look_phase = LookPhase.PAUSE_AFTER
			move_direction = _look_base_direction
			_look_timer = look_pause_duration
		LookPhase.PAUSE_AFTER:
			return true
	return false


func _start_searching() -> void:
	current_state = State.SEARCHING


func _start_looking() -> void:
	current_state = State.LOOKING
	_look_base_direction = move_direction if move_direction.length() > 0.1 else Vector2.RIGHT
	_look_phase = LookPhase.PAUSE_BEFORE
	_look_timer = look_pause_duration


func _move_toward_nav_target() -> void:
	if navigation_agent.is_navigation_finished():
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		return

	var next_point := navigation_agent.get_next_path_position()
	move_direction = (next_point - body.global_position).normalized()
	body.velocity = body.velocity.lerp(move_direction * speed, acceleration)


func _move_toward_point(point: Vector2, delta: float) -> void:
	var to_point := point - body.global_position
	var distance := to_point.length()
	if distance < 1.0:
		body.velocity = body.velocity.lerp(Vector2.ZERO, friction)
		return

	move_direction = to_point / distance

	# The bait point only creeps forward a little each frame, so without this
	# cap the guard (moving at full `speed`) would overshoot it every frame
	# and flip direction trying to correct, oscillating back and forth. Cap
	# the closing speed to what's needed to just reach the point this frame.
	var closing_speed := minf(speed, distance / delta)
	body.velocity = body.velocity.lerp(move_direction * closing_speed, acceleration)
