extends State

@export var idle_state: State
@export var frames_cooldown: int = 55

var timer: float

func enter() -> void:
	timer = frames_cooldown / 60.0
	actor.dash_open = false
	actor.dash_cooldown_change.emit(0)

func physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	actor.velocity = input_dir * actor.normal_velocity
	actor.move_and_slide()

	timer -= delta
	
	var progress: float = 1.0 - (timer / (frames_cooldown / 60.0))
	actor.dash_cooldown_change.emit(progress)
	
	if timer <= 0.0:
		actor.dash_open = true
		actor.dash_cooldown_change.emit(100)
		state_machine.change_state_to(idle_state)
