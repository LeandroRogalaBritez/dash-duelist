extends State

func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.sound_bank.playSfx("player_death")
	actor.sprite.play("die")
	actor.died.emit()

func physics_process(_delta: float) -> void:
	pass
