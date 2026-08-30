extends State

@export var cooldown_state: State
@export var dash_velocity: int = 576
@export var dash_duration: int = 12

var timer: float

func enter() -> void:
	timer = dash_duration / 60.0
	actor.iframes_active = true
	actor.sound_bank.play("dash")

func physics_process(_delta: float) -> void:
	actor.velocity = actor.last_direction * dash_velocity
	actor.move_and_slide()

	timer -= _delta
	if timer <= 0.0:
		state_machine.change_state_to(cooldown_state)

func exit() -> void:
	actor.iframes_active = false
