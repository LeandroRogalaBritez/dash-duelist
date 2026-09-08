extends State

@export var dash_state: State
@export var idle_state: State

func enter() -> void:
	actor.play_anim("walk")

func physics_process(_delta: float) -> void:
	actor.move_with_input()

	if actor.wants_dash():
		state_machine.change_state_to(dash_state)
		return

	if actor.input_dir == Vector2.ZERO:
		state_machine.change_state_to(idle_state)

