extends State

@export var dash_state: State
@export var walk_state: State

func enter() -> void:
	actor.play_anim("idle")

func physics_process(_delta: float) -> void:
	actor.move_with_input()

	if actor.wants_dash():
		state_machine.change_state_to(dash_state)
		return

	# input_dir, não last_direction: last_direction nunca volta a zero (o dash
	# precisa da última direção válida), então usá-la aqui deixava o player
	# preso em Walk para sempre.
	if actor.input_dir != Vector2.ZERO:
		state_machine.change_state_to(walk_state)
