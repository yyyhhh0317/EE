class_name CombatResolver
extends RefCounted
## 伤害结算管线（M1 最小版：无词条，仅预留扩展点）。
## 后续接入 Modifier 系统时，在 calculate_damage 处做加成/减免/行为钩子。

## 计算最终伤害。
static func calculate_damage(base_damage: float, _target: Node = null) -> float:
	return maxf(0.0, base_damage)

## 对目标施加伤害，返回实际造成的伤害。
static func deal_damage(target: Node, base_damage: float, source: Node = null) -> float:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return 0.0
	var dealt := calculate_damage(base_damage, target)
	target.take_damage(dealt, source)
	EventBus.emit("combat.damage_dealt", {"target": target, "amount": dealt, "source": source})
	return dealt
