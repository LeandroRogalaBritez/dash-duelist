extends Node
class_name SoundBank

@export var sounds: Array[SoundEntry] = []

func play(soundName: String) -> void:
	for entry in sounds:
		if entry.name == soundName:
			SoundManager.play_sfx(entry.som)
			return
	push_warning("Som '%s' não configurado neste SoundBank." % soundName)
