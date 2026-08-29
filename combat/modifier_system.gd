class_name ModifierSystem
extends RefCounted
## 词条系统：统一处理属性修饰 + 行为钩子 + 层叠。
## M2 只实现最基础的一层（属性加减/乘、on_hit/on_tick 钩子）；M5 扩展为数据驱动的行为库。

var _active: Dictionary = {}  # mod_id -> {"stacks": int, "data": Dictionary}

## 应用一个词条，可选指定叠加层数（叠加不超过 max_stacks）。
func apply(mod_id: String, stacks: int = 1) -> void:
	var data := DataManager.get_modifier(mod_id)
	if data.is_empty():
		push_warning("ModifierSystem: 未知词条 %s" % mod_id)
		return
	if _active.has(mod_id):
		var max_stacks := int(data.get("max_stacks", 1))
		_active[mod_id]["stacks"] = mini(int(_active[mod_id]["stacks"]) + stacks, max_stacks)
	else:
		_active[mod_id] = {"stacks": stacks, "data": data}

func remove(mod_id: String) -> void:
	_active.erase(mod_id)

func has(mod_id: String) -> bool:
	return _active.has(mod_id)

func get_stacks(mod_id: String) -> int:
	return int(_active.get(mod_id, {}).get("stacks", 0))

## 计算最终属性：base * (1 + Σmult) + Σadd。
func get_stat(base: float, stat: String) -> float:
	var add := 0.0
	var mult := 0.0
	for mod_id in _active:
		var entry: Dictionary = _active[mod_id]
		var data: Dictionary = entry["data"]
		if data.get("stat", "") != stat:
			continue
		var value: float = float(data.get("value", 0.0)) * int(entry["stacks"])
		if data.get("operation", "add") == "mult":
			mult += value
		else:
			add += value
	return base * (1.0 + mult) + add

## 触发行为钩子（on_hit / on_kill / on_tick ...）。
func trigger_hook(hook: String, context: Dictionary) -> void:
	for mod_id in _active.keys():
		var entry: Dictionary = _active[mod_id]
		var data: Dictionary = entry["data"]
		var hooks: Array = data.get("hooks", [])
		if hook in hooks:
			# 通用规则：层叠型词条在命中时叠层。
			if hook == "on_hit" and data.get("type", "") == "stack":
				add_stack(mod_id, 1)
			_run_hook(mod_id, hook, context)

func add_stack(mod_id: String, amount: int = 1) -> void:
	if not _active.has(mod_id):
		return
	var data: Dictionary = _active[mod_id]["data"]
	_active[mod_id]["stacks"] = mini(int(_active[mod_id]["stacks"]) + amount, int(data.get("max_stacks", 1)))

## 具体钩子效果（代码规则，M5 扩展为数据驱动行为库）。
func _run_hook(mod_id: String, hook: String, context: Dictionary) -> void:
	match hook:
		"on_tick":
			if mod_id == "mod_instability_drain":
				var owner: Node = context.get("owner")
				if owner == null:
					return
				var drain: float = float(_active[mod_id]["data"].get("value", 3.0)) * int(_active[mod_id]["stacks"])
				if owner.has_method("take_raw_damage"):
					owner.take_raw_damage(drain)
				elif owner.has_method("take_damage"):
					owner.take_damage(drain)
