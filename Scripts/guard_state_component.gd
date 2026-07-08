extends Node
class_name GuardStateComponent

enum State { IDLE, ALERT, ATTACK, SEARCHING, LOOKING }

# LOOP: walk patrol_path on a continuous loop (requires the path's curve to
#       form a closed shape, or PathFollow2D.loop = true). If path_stop_interval
#       is > 0, periodically pauses to look around (reusing the LOOKING state)
#       before continuing.
# PING_PONG: walk patrol_path and reverse direction at each end. Also honors
#       path_stop_interval, same as LOOP.
# WAYPOINTS: step between patrol_waypoints in order, pausing to look around
#       (reusing the LOOKING state) at each stop before moving on.
# STATIONARY: never move; repeat the look cycle forever on the spot.
enum PatrolMode { LOOP, PING_PONG, WAYPOINTS, STATIONARY }

# LOOP: every repeat walks look_angles in the same order, rounding back to
#       the first angle each time.
# PING_PONG: reverses the walk order each time the sequence completes, so
#       it alternates which end it visits first instead of always
#       restarting from look_angles[0].
enum LookCycleMode { LOOP, PING_PONG }

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
# Seconds of walking along patrol_path between look-around stops, for LOOP/
# PING_PONG only. <= 0 disables stopping (the guard just keeps walking).
var path_stop_interval: float = 0.0

# Sequence of angles (degrees, relative to whichever direction the guard was
# facing when the look cycle started) the guard turns through in order,
# holding at each for look_hold_duration before turning to the next. A
# pause of look_pause_duration is added before the first angle and after the
# last. Include 0.0 as the last entry to have the guard end up facing the way
# it started. Whether repeats walk this list in the same order every time or
# alternate direction is controlled by look_cycle_mode.
var look_angles: Array[float] = [-60.0, 60.0, 0.0]
var look_pause_duration: float = 0.6
var look_hold_duration: float = 0.5
# Degrees/second the guard turns at between look angles; turning is gradual
# rather than snapping instantly to each new angle.
var look_turn_speed_degrees: float = 240.0
var look_cycle_mode: LookCycleMode = LookCycleMode.LOOP

var current_state: State = State.IDLE
var move_direction := Vector2.RIGHT
var target: Node2D = null
var last_known_position: Vector2

var _patrol_target_set := false
var _patrol_direction := 1
var _waypoint_index := 0
var _path_walk_timer := 0.0

var _look_base_direction := Vector2.RIGHT
var _look_index := 0
var _look_turning := false
var _look_current_angle := 0.0
var _look_hold_timer := 0.0
var _look_walk_direction := 1

var _stationary_look_started := false
var _stationary_origin_set := false
var _stationary_origin := Vector2.ZERO


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

	if path_stop_interval > 0.0:
		_path_walk_timer += delta
		if _path_walk_timer >= path_stop_interval:
			_path_walk_timer = 0.0
			_start_looking()
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


# STATIONARY patrol holds a single spot, repeating the look cycle forever
# instead of resolving back to IDLE after one pass. If ALERT/ATTACK/SEARCHING
# has pulled the guard away from that spot (chasing or investigating the
# player), it walks back to its original position first before resuming.
func _handle_patrol_stationary(delta: float) -> void:
	if not _stationary_origin_set:
		_stationary_origin_set = true
		_stationary_origin = body.global_position

	navigation_agent.target_position = _stationary_origin
	if not navigation_agent.is_navigation_finished():
		_stationary_look_started = false
		_move_toward_nav_target()
		return

	body.velocity = body.velocity.lerp(Vector2.ZERO, friction)

	if not _stationary_look_started:
		_stationary_look_started = true
		_look_base_direction = move_direction if move_direction.length() > 0.1 else Vector2.RIGHT
		_start_look_cycle()

	if _advance_look_cycle(delta):
		_start_look_cycle()


func _start_searching() -> void:
	current_state = State.SEARCHING


func _start_looking() -> void:
	current_state = State.LOOKING
	_look_base_direction = move_direction if move_direction.length() > 0.1 else Vector2.RIGHT
	_start_look_cycle()


# Resets the look cycle to its first stop: paused at the base direction
# (angle 0), about to turn to look_angles[0].
func _start_look_cycle() -> void:
	_look_index = 0
	_look_turning = false
	_look_current_angle = 0.0
	_look_hold_timer = _look_stop_duration(0)
	move_direction = _look_base_direction


# A look cycle visits look_angles.size() + 2 stops: a pause at the base
# direction, one stop per entry in look_angles (turning smoothly between
# them at look_turn_speed_degrees), then a final pause back at the base
# direction. Advances by delta and returns true once that final pause ends.
func _advance_look_cycle(delta: float) -> bool:
	if _look_turning:
		var target_angle := _look_stop_angle(_look_index)
		var max_step := deg_to_rad(look_turn_speed_degrees) * delta
		var diff := wrapf(target_angle - _look_current_angle, -PI, PI)
		if absf(diff) <= max_step:
			_look_current_angle = target_angle
			_look_turning = false
			_look_hold_timer = _look_stop_duration(_look_index)
		else:
			_look_current_angle += clampf(diff, -max_step, max_step)
	else:
		_look_hold_timer -= delta
		if _look_hold_timer <= 0.0:
			_look_index += 1
			if _look_index > look_angles.size() + 1:
				if look_cycle_mode == LookCycleMode.PING_PONG:
					_look_walk_direction *= -1
				return true
			_look_turning = true

	move_direction = _look_base_direction.rotated(_look_current_angle)
	return false


# Target angle (radians, relative to _look_base_direction) for stop `index`.
# Index 0 and the final index are the bookend pauses at the base direction;
# everything in between maps into look_angles, walked forwards or backwards
# depending on _look_walk_direction (flipped each completed cycle in
# PING_PONG mode so it alternates which end it visits first).
func _look_stop_angle(index: int) -> float:
	if index >= 1 and index <= look_angles.size():
		var array_index := index - 1 if _look_walk_direction >= 0 else look_angles.size() - index
		return deg_to_rad(look_angles[array_index])
	return 0.0


# How long to hold at stop `index`: look_pause_duration for the bookend
# stops, look_hold_duration for every angle in between.
func _look_stop_duration(index: int) -> float:
	if index == 0 or index == look_angles.size() + 1:
		return look_pause_duration
	return look_hold_duration


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
