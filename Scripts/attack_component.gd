extends Node2D
class_name AttackComponent

signal attack_started
signal attack_finished

@export var hitbox: HitboxComponent
@export var active_time: float = 0.15 
@export var cooldown_time: float = 0.6

var _can_attack: bool = true

func attack() -> void:
	if not _can_attack or not hitbox:
		return

	_can_attack = false
	attack_started.emit()

	hitbox.monitoring = true
	await get_tree().create_timer(active_time).timeout
	hitbox.monitoring = false
	attack_finished.emit()

	await get_tree().create_timer(cooldown_time).timeout
	_can_attack = true

func can_attack() -> bool:
	return _can_attack
