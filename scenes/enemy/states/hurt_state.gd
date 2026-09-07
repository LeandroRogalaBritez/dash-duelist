extends State


func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.sprite.play("hurt")
	await actor.sprite.animation_finished
	state_machine.change_state_to(state_machine.previous_state)
