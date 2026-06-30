extends Area2D
class_name HitboxComponent

@export var damage: int = 25
@export var knockout: bool = false # true = stealth takedown, false = lethal/combat hit

func _ready() -> void:
	monitoring = false # off by default - AttackComponent turns it on for active frames
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		area.take_hit(damage, knockout)
