@tool
extends Area2D
class_name VisionComponent

signal target_spotted(body: Node2D)
signal target_lost(body: Node2D)

@export var view_distance: float = 90.0:
	set(value):
		view_distance = value
		if is_inside_tree():
			_rebuild_shape()

@export_range(0.0, 360.0, 0.5) var view_angle_degrees: float = 90.0:
	set(value):
		view_angle_degrees = value
		if is_inside_tree():
			_rebuild_shape()

@export var target_group: String = "player"
@export_flags_2d_physics var obstruction_mask: int = 1
@export var self_body: CollisionObject2D

# Grace period before actually declaring a target lost. A body's active
# collision shape can flicker in/out of the cone's edge for a frame or two
# (especially the smaller wall-slide shapes), which would otherwise cause
# target_lost/target_spotted to fire rapidly back-to-back.
@export var lose_sight_grace: float = 0.35

@onready var _collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

var _candidates: Array[Node2D] = []
var _visible_targets: Array[Node2D] = []
var _grace_timers: Dictionary = {}

func _ready() -> void:
	_rebuild_shape()
	if Engine.is_editor_hint():
		return

	monitorable = false
	if not self_body:
		var ancestor := get_parent()
		while ancestor and not (ancestor is CollisionObject2D):
			ancestor = ancestor.get_parent()
		self_body = ancestor as CollisionObject2D

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_visibility(delta)

func has_line_of_sight(body: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var target_position := _get_active_shape_position(body)
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, obstruction_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var exclude: Array[RID] = []
	if self_body:
		exclude.append(self_body.get_rid())
	if body is CollisionObject2D:
		exclude.append(body.get_rid())
	query.exclude = exclude

	return space_state.intersect_ray(query).is_empty()

# Aim at whichever collision shape is currently enabled on the body (e.g. the
# smaller wall-slide shape) instead of the body's fixed origin, so shrinking
# the active shape while hiding against a wall actually affects detection.
func _get_active_shape_position(body: Node2D) -> Vector2:
	if body is CollisionObject2D:
		var positions: Array[Vector2] = []
		for owner_id in body.get_shape_owners():
			var owner_node: Object = body.shape_owner_get_owner(owner_id)
			if owner_node is CollisionShape2D and not (owner_node as CollisionShape2D).disabled:
				positions.append((owner_node as CollisionShape2D).global_position)
		if positions.size() > 0:
			var sum := Vector2.ZERO
			for p in positions:
				sum += p
			return sum / positions.size()
	return body.global_position

func get_visible_targets() -> Array[Node2D]:
	return _visible_targets.duplicate()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group) and body not in _candidates:
		_candidates.append(body)

func _on_body_exited(body: Node2D) -> void:
	_candidates.erase(body)
	if body in _visible_targets:
		_start_losing(body)

func _update_visibility(delta: float) -> void:
	for body in _candidates.duplicate():
		if not is_instance_valid(body):
			_candidates.erase(body)
			continue

		var visible_now: bool = has_line_of_sight(body)
		var was_visible: bool = body in _visible_targets

		if visible_now:
			_grace_timers.erase(body)
			if not was_visible:
				_visible_targets.append(body)
				target_spotted.emit(body)
		elif was_visible:
			_start_losing(body)

	for body in _grace_timers.keys().duplicate():
		if not is_instance_valid(body):
			_finalize_loss(body)
			continue
		_grace_timers[body] -= delta
		if _grace_timers[body] <= 0.0:
			_finalize_loss(body)

func _start_losing(body: Node2D) -> void:
	if body not in _grace_timers:
		_grace_timers[body] = lose_sight_grace

func _finalize_loss(body: Node2D) -> void:
	_grace_timers.erase(body)
	if body in _visible_targets:
		_visible_targets.erase(body)
		target_lost.emit(body)

func _rebuild_shape() -> void:
	if not _collision_polygon:
		_collision_polygon = get_node_or_null("CollisionPolygon2D")
	if not _collision_polygon:
		return

	var half_angle := deg_to_rad(view_angle_degrees) * 0.5
	var segments := 12
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t: float = lerp(-half_angle, half_angle, float(i) / float(segments))
		points.append(Vector2(cos(t), sin(t)) * view_distance)

	_collision_polygon.polygon = points
