extends State

@export var dash_state: State

func physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	actor.velocity = input_dir * actor.normal_velocity
	actor.move_and_slide()

	if Input.is_action_just_pressed("dash") and actor.dash_open:
		state_machine.change_state_to(dash_state)
