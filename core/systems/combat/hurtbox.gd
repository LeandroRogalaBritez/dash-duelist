extends Area2D
class_name Hurtbox

const DAMAGE := 20

@onready var actor: Combatant = get_parent() as Combatant

func _ready() -> void:
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

func _on_hit(other: Node) -> void:
	# Guard de identidade explícito. Sem ele, o Hurtbox do player enxerga o
	# próprio Hitbox assim que o dash o torna monitorable (os dois estão no
	# mesmo nó pai). Não dá para depender dos i-frames aqui: eles só cobrem
	# esse caso por coincidência de timing.
	if other == actor or other.get_parent() == actor:
		return

	# Funil: quem sabe decidir o próprio dano decide (o Player, que em PVP
	# delega a decisão ao host). O default de Combatant.on_hurtbox_hit()
	# mantém o Enemy exatamente como era.
	actor.on_hurtbox_hit(other, DAMAGE)
