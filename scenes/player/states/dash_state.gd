extends State

@export var cooldown_state: State
@export var dash_velocity: int = 576
@export var dash_duration: int = 12

var timer: float

func enter() -> void:
	timer = dash_duration / 60.0
	actor.dash_iframes_active = true
	actor.hitbox.monitoring = true
	actor.hitbox.monitorable = true
	actor.sound_bank.playSfx("dash", -15.0)
	actor.sprite.play("walk")

func physics_process(_delta: float) -> void:
	actor.velocity = actor.last_direction * dash_velocity
	actor.move_and_slide()

	timer -= _delta
	if timer <= 0.0:
		state_machine.change_state_to(cooldown_state)

func exit() -> void:
	actor.dash_iframes_active = false
	actor.hitbox.monitoring = false
	actor.hitbox.monitorable = false
