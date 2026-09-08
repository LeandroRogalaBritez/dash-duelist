extends State

@export var idle_state: State
@export var frames_cooldown: int = 55

var timer: float

func enter() -> void:
	timer = frames_cooldown / 60.0
	actor.dash_open = false
	actor.set_dash_progress(0)
	actor.play_anim("idle")

func physics_process(delta: float) -> void:
	actor.move_with_input()

	timer -= delta
	
	var progress: float = 1.0 - (timer / (frames_cooldown / 60.0))
	actor.set_dash_progress(progress * 100)
	
	if timer <= 0.0:
		actor.dash_open = true
		actor.set_dash_progress(100)
		state_machine.change_state_to(idle_state)
