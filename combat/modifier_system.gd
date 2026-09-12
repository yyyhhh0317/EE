class_name ModifierSystem
extends RefCounted
## 词条系统 v2：多源词条 + 动态叠层 + 乘法稀释 + 行为钩子。
##
## - 多源：set_source(source_id, {mod_id: stacks}) 由 BuildManager 按构筑重建；
##   apply()/remove() 操作 "runtime" 源（事件/一次性效果）。
## - 动态叠层：add_stack() 计入 _dynamic，随源移除自动清理（如怒的命中叠层）。
## - 乘法稀释：set_mod_dilution(mod_id, coeff)，在 get_stat 时乘到数值上。
## - 钩子：on_hit（恐惧迟滞/哀恸汲取/怒叠层）、on_kill（欢愉丰收）。

var _sources: Dictionary = {}   # source_id -> {mod_id: int}
var _dynamic: Dictionary = {}   # mod_id -> int（动态叠层）
var _dilution: Dictionary = {}  # mod_id -> float（乘法稀释系数）

## 应用词条到 runtime 源（层数受该词条 max_stacks 约束）。
func apply(mod_id: String, stacks: int = 1) -> void:
	var data := DataManager.get_modifier(mod_id)
	if data.is_empty():
		push_warning("ModifierSystem: 未知词条 %s" % mod_id)
		return
	var src: Dictionary = _sources.get("runtime", {})
	var cur := int(src.get(mod_id, 0))
	src[mod_id] = mini(cur + stacks, int(data.get("max_stacks", 1)))
	_sources["runtime"] = src

## 用给定词条集整体替换某个源（build 源由 BuildManager 维护）。
func set_source(source_id: String, mods: Dictionary) -> void:
	_sources[source_id] = mods.duplicate()
	# 清理：不再存在于任何源的词条，其动态叠层一并清除。
	for mid in _dynamic.keys():
		if not has(mid):
			_dynamic.erase(mid)

## 从所有源移除词条。
func remove(mod_id: String) -> void:
	for src in _sources.values():
		src.erase(mod_id)
	_dynamic.erase(mod_id)

func has(mod_id: String) -> bool:
	for src in _sources.values():
		if int(src.get(mod_id, 0)) > 0:
			return true
	return int(_dynamic.get(mod_id, 0)) > 0

## 静态源合计（不含动态叠层）。
func base_stacks(mod_id: String) -> int:
	var n := 0
	for src in _sources.values():
		n += int(src.get(mod_id, 0))
	return n

## 总叠层（静态 + 动态）。
func total_stacks(mod_id: String) -> int:
	return base_stacks(mod_id) + int(_dynamic.get(mod_id, 0))

func get_stacks(mod_id: String) -> int:
	return total_stacks(mod_id)

func add_stack(mod_id: String, amount: int = 1) -> void:
	if not has(mod_id):
		return
	var data := DataManager.get_modifier(mod_id)
	if data.is_empty():
		return
	var cap := int(data.get("max_stacks", 1))
	var target := mini(total_stacks(mod_id) + amount, cap)
	_dynamic[mod_id] = maxi(0, target - base_stacks(mod_id))

## ---- 乘法稀释 ----
func set_mod_dilution(mod_id: String, coeff: float) -> void:
	_dilution[mod_id] = coeff

func clear_mod_dilution() -> void:
	_dilution.clear()

## ---- 属性计算：base * (1 + Σmult) + Σadd，词条数值 × 叠层 × 稀释 ----
func get_stat(base: float, stat: String) -> float:
	var add := 0.0
	var mult := 0.0
	for mid in _all_mod_ids():
		var data := DataManager.get_modifier(mid)
		if data.is_empty() or data.get("stat", "") != stat:
			continue
		var stacks := mini(total_stacks(mid), int(data.get("max_stacks", 1)))
		var value: float = float(data.get("value", 0.0)) * float(stacks) * float(_dilution.get(mid, 1.0))
		if data.get("operation", "add") == "mult":
			mult += value
		else:
			add += value
	return base * (1.0 + mult) + add

## ---- 行为钩子 ----
func trigger_hook(hook: String, context: Dictionary) -> void:
	for mid in _all_mod_ids():
		var data := DataManager.get_modifier(mid)
		if data.is_empty():
			continue
		var hooks: Array = data.get("hooks", [])
		if hook in hooks:
			# 通用规则：层叠型词条在命中时叠层。
			if hook == "on_hit" and data.get("type", "") == "stack":
				add_stack(mid, 1)
			_run_hook(mid, hook, context)

## 具体钩子效果（代码规则）。
func _run_hook(mod_id: String, hook: String, context: Dictionary) -> void:
	match hook:
		"on_hit":
			match mod_id:
				"mod_fear_slow":
					var target: Node = context.get("target")
					if target != null and target.has_method("apply_slow"):
						var params: Dictionary = DataManager.get_modifier(mod_id).get("params", {})
						target.apply_slow(float(params.get("slow_pct", 0.3)), float(params.get("slow_time", 1.5)))
				"mod_sorrow_lifesteal":
					var owner: Node = context.get("owner")
					if owner != null and owner.has_method("heal"):
						owner.heal(float(DataManager.get_modifier(mod_id).get("value", 1.0)))
		"on_kill":
			match mod_id:
				"mod_joy_coin":
					RunManager.gain_currency(int(DataManager.get_modifier(mod_id).get("value", 2.0)))

func _all_mod_ids() -> Array:
	var ids := {}
	for src in _sources.values():
		for mid in src:
			if int(src[mid]) > 0:
				ids[mid] = true
	for mid in _dynamic:
		if int(_dynamic[mid]) > 0:
			ids[mid] = true
	return ids.keys()
