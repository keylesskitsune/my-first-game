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

@onready var _collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

var _candidates: Array[Node2D] = []
var _visible_targets: Array[Node2D] = []

func _ready() -> void:
	_rebuild_shape()
	if Engine.is_editor_hint():
		return

	monitorable = false
	if not self_body:
		self_body = get_parent() as CollisionObject2D

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_visibility()

func has_line_of_sight(body: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, body.global_position, obstruction_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var exclude: Array[RID] = []
	if self_body:
		exclude.append(self_body.get_rid())
	if body is CollisionObject2D:
		exclude.append(body.get_rid())
	query.exclude = exclude

	return space_state.intersect_ray(query).is_empty()

func get_visible_targets() -> Array[Node2D]:
	return _visible_targets.duplicate()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group) and body not in _candidates:
		_candidates.append(body)

func _on_body_exited(body: Node2D) -> void:
	_candidates.erase(body)
	if body in _visible_targets:
		_visible_targets.erase(body)
		target_lost.emit(body)

func _update_visibility() -> void:
	for body in _candidates.duplicate():
		if not is_instance_valid(body):
			_candidates.erase(body)
			continue

		var visible_now: bool = has_line_of_sight(body)
		var was_visible: bool = body in _visible_targets

		if visible_now and not was_visible:
			_visible_targets.append(body)
			target_spotted.emit(body)
		elif not visible_now and was_visible:
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
