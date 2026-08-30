extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Player.dash_cooldown_change.connect($Hud._on_dash_cooldown_change)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
