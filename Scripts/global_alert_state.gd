extends Node

# Autoload singleton (registered as "GlobalAlertState" in project.godot).
# Tracks the shared, game-wide awareness of the player across all guards,
# independent of any single guard's own vision. Radar and screen-effect
# systems can subscribe to `state_changed` / `player_position_updated`
# instead of polling individual guards.

signal state_changed(new_state: State)
signal player_position_updated(position: Vector2)

enum State {
	CALM,
	ALERT,
	SEARCHING, # TODO: guards give up converging and fall back to investigating the area
}

# Delay between a guard spotting the player and the rest of the guard force
# reacting, simulating the time it takes to radio in a sighting.
@export var alert_delay: float = 1.0

var current_state: State = State.CALM
var last_known_position: Vector2

var _pending_position: Vector2
var _pending_timer: float = -1.0


# Called by any guard that currently has eyes on the player.
func report_sighting(position: Vector2) -> void:
	if current_state == State.CALM:
		_pending_position = position
		if _pending_timer < 0.0:
			_pending_timer = alert_delay
	else:
		last_known_position = position
		player_position_updated.emit(position)


func _process(delta: float) -> void:
	if _pending_timer < 0.0:
		return

	_pending_timer -= delta
	if _pending_timer <= 0.0:
		_pending_timer = -1.0
		_enter_alert()


func _enter_alert() -> void:
	current_state = State.ALERT
	last_known_position = _pending_position
	state_changed.emit(current_state)
	player_position_updated.emit(last_known_position)
