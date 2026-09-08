extends State

func enter() -> void:
	actor.damage_iframes_active = true
	actor.velocity = Vector2.ZERO
	actor.play_sfx("player_hit")
	actor.play_anim("hurt")
	await actor.sprite.animation_finished

	# Se o player morreu durante a animação de hurt, o state machine já está em
	# Die — sem este guard o await pendente o arrancaria de volta, e com vida
	# única isso quebra o duelo.
	if actor.is_dead:
		return

	state_machine.change_state_to(state_machine.previous_state)
	await get_tree().create_timer(40.0 / 60.0).timeout

	if actor.is_dead:
		return

	actor.damage_iframes_active = false
