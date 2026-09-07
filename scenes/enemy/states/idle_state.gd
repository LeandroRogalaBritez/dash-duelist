extends State

@export var chase_state: State

func enter() -> void:
	actor.sprite.play("idle")

func physics_process(_delta: float) -> void:
	if actor.distance_to_player() <= actor.detection_range:
		state_machine.change_state_to(chase_state)
