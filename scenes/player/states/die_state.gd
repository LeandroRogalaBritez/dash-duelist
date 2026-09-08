extends State

func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.play_sfx("player_death")
	actor.play_anim("die")
	actor.died.emit()

func physics_process(_delta: float) -> void:
	pass
