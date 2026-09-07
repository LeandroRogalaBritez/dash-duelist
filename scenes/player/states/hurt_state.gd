extends State

func enter() -> void:
	actor.damage_iframes_active = true
	actor.velocity = Vector2.ZERO
	actor.sound_bank.playSfx("player_hit")
	actor.sprite.play("hurt")
	await actor.sprite.animation_finished
	state_machine.change_state_to(state_machine.previous_state)
	await get_tree().create_timer(40.0 / 60.0).timeout
	actor.damage_iframes_active = false
