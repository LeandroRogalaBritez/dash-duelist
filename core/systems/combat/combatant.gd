extends CharacterBody2D
class_name Combatant

# Contrato de combate compartilhado por Player e Enemy.
#
# Existe para dar ao Hurtbox um tipo concreto para chamar, em vez de sondar um
# Node com has_method(). Os defaults abaixo reproduzem exatamente o caminho que
# o Hurtbox usava para quem não implementava on_hurtbox_hit() — hoje, o Enemy.

# Sem i-frames por padrão. O Player sobrescreve: lá o dash e os i-frames de
# dano concedem invulnerabilidade.
func is_invulnerable() -> bool:
	return false

# Ponto de entrada único do Hurtbox. O default respeita invulnerabilidade e
# aplica o dano direto. O Player sobrescreve porque em PVP quem decide o HP é
# o host, não a detecção local.
func on_hurtbox_hit(_other: Node, amount: int) -> void:
	if is_invulnerable():
		return
	take_damage(amount)

# Abstrato na prática: cada combatente decide o que "levar dano" significa.
func take_damage(_amount: int) -> void:
	push_error("Combatant '%s' não implementa take_damage()." % name)
