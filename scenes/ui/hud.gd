extends CanvasLayer

@onready var cooldown_dash: ProgressBar = $CooldownDash

func _on_dash_cooldown_change(_progress: float) -> void:
	cooldown_dash.value = _progress * 100.0
