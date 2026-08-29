class_name HealthComponent
extends Node
## 生命组件：管理 HP 与死亡判定（组件组合，玩家 / 敌人复用）。

signal damaged(amount: float, new_hp: float)
signal died

@export var max_hp: float = 100.0

var hp: float

func _ready() -> void:
	hp = max_hp

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)

func is_dead() -> bool:
	return hp <= 0.0
