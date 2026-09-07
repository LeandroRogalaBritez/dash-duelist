extends State

@export var attack_state: State
@export var idle_state: State

func enter() -> void:
	actor.sprite.play("walk")
	
func physics_process(_delta: float) -> void:
	actor.move_toward_player()

	var dist = actor.distance_to_player()
	if dist > actor.detection_range:
		state_machine.change_state_to(idle_state)
	elif dist <= actor.attack_range:
		state_machine.change_state_to(attack_state)
