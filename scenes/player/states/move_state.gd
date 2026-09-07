extends State

@export var dash_state: State
@export var idle_state: State

func enter() -> void:
	actor.sprite.play("walk")

func physics_process(_delta: float) -> void:
	actor.move_with_input()

	if Input.is_action_just_pressed("dash") and actor.dash_open:
		state_machine.change_state_to(dash_state)
		return
	
	if actor.last_direction == Vector2.ZERO:
		state_machine.change_state_to(idle_state)
	
	
