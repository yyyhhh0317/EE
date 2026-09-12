class_name CombatResolver
extends RefCounted
## 伤害结算管线（v0.2）：
## - 对玩家伤害应用动态难度（RunManager.enemy_damage_mult）
## - deal_damage 支持携带 meta（如 crit）供表现层渲染情绪化伤害数字。

## 计算最终伤害。
static func calculate_damage(base_damage: float, target: Node = null) -> float:
	var dealt := maxf(0.0, base_damage)
	if target != null and is_instance_valid(target) and target.is_in_group("player"):
		dealt *= RunManager.enemy_damage_mult()
	return dealt

## 对目标施加伤害，返回实际造成的伤害。
## meta 可选：{"crit": true} 等，透传给 combat.damage_dealt。
static func deal_damage(target: Node, base_damage: float, source: Node = null, meta: Dictionary = {}) -> float:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0.0
	var dealt := calculate_damage(base_damage, target)
	target.take_damage(dealt, source)
	EventBus.emit("combat.damage_dealt", {"target": target, "amount": dealt, "source": source, "meta": meta})
	return dealt
