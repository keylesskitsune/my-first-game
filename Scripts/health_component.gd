extends Node2D
class_name HealthComponent

signal health_changed(current: int, max_hp: int)
signal died
signal damaged(amount: int)

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return

	current_health = max(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0

func knockout() -> void:
	take_damage(current_health)
