extends State


func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.collision_layer = 0
	actor.hurtbox.monitoring = false
	actor.sprite.play("death")
	actor.sound_bank.playSfx("enemy_death")
	await actor.sprite.animation_finished
	actor.died.emit()
	actor.queue_free()
