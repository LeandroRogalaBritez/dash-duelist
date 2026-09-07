extends State

@export var chase_state: State

var time_since_last_shot: float = 0.0


func enter() -> void:
	actor.sprite.play("walk")
	time_since_last_shot = 0.0

func physics_process(delta: float) -> void:
	actor.move_toward_player()

	var dist = actor.distance_to_player()
	if dist > actor.attack_range:
		state_machine.change_state_to(chase_state)
		return

	time_since_last_shot += delta
	if time_since_last_shot >= actor.attack_cooldown_frames / 60.0:
		actor.shoot()
		time_since_last_shot = 0.0
