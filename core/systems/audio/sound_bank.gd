extends Node
class_name SoundBank

@export var sounds: Array[SoundEntry] = []

func playSfx(soundName: String, volume_db: float = 0.0) -> void:
	for entry in sounds:
		if entry.name == soundName:
			SoundManager.play_sfx(entry.sound, volume_db)
			return
	push_warning("Som '%s' não configurado neste SoundBank." % soundName)
	
func playMusic(soundName: String, volume_db: float = 0.0) -> void:
	for entry in sounds:
		if entry.name == soundName:
			SoundManager.play_music(entry.sound, volume_db)
			return
	push_warning("Som '%s' não configurado neste SoundBank." % soundName)
