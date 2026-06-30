extends Area2D
class_name HurtboxComponent

signal hit_received(damage: int)

@export var health_component: HealthComponent

func _ready() -> void:
	monitoring = false
	monitorable = true

func take_hit(damage: int, knockout: bool = false) -> void:
	hit_received.emit(damage)
	if not health_component:
		push_warning("HurtboxComponent has no HealthComponent assigned")
		return

	if knockout:
		health_component.knockout()
	else:
		health_component.take_damage(damage)
