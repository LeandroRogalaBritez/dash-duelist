extends State


func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.collision_layer = 0
	# set_deferred: este estado é alcançado de dentro do area_entered do Hurtbox,
	# e o Godot bloqueia mexer em monitoring durante a emissão do próprio sinal
	# — a atribuição direta era descartada com erro no console.
	actor.hurtbox.set_deferred("monitoring", false)
	actor.sprite.play("death")
	actor.sound_bank.playSfx("enemy_death")
	await actor.sprite.animation_finished
	actor.died.emit()
	actor.queue_free()
