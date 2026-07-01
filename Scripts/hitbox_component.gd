extends Area2D
class_name HitboxComponent

@export var damage: int = 25
@export var knockout: bool = false # true = stealth takedown, false = lethal/combat hit
@export var backstab_dot_threshold: float = -0.5 # how directly behind the target counts as a backstab

func _ready() -> void:
	monitoring = false # off by default - AttackComponent turns it on for active frames
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	print("Hitbox touched: ", area.name)
	if area is HurtboxComponent:
		var is_takedown = knockout or _is_behind_target(area)
		if is_takedown:
			print("Takedown!")
		area.take_hit(damage, is_takedown)

func _is_behind_target(area: Area2D) -> bool:
	var target = area.get_parent()
	if target == null or not ("facing_direction" in target):
		return false

	var facing: Vector2 = target.facing_direction
	if facing == Vector2.ZERO:
		return false

	var direction_to_attacker = (global_position - target.global_position).normalized()
	return facing.dot(direction_to_attacker) < backstab_dot_threshold
