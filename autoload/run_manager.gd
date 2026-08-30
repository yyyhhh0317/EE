extends Node
## RunManager —— 单局运行状态：章节/房间/精华/货币/构筑/失控值。
## M3：节点图二选一推进 + 货币；M2：注射/失控值/稳定剂。

const INSTABILITY_OVERFLOW_THRESHOLD := 60.0
const INSTABILITY_MAX := 100.0
const STABILIZER_REDUCE := 20.0
const REST_INSTABILITY_REDUCE := 25.0

var is_running: bool = false
var current_chapter: int = 1
var current_choice_index: int = 0
var chapter_choices: Array = []  # [ [room, room], [room, room], ..., [boss] ]

var instability: float = 0.0
var is_unstable: bool = false
var essence: Dictionary = {}  # factor_id -> int
var currency: int = 0

var injected_factors: Array[String] = []

## 开始一局（生成章节）。
func start_run(chapter: int = 1) -> void:
	is_running = true
	current_chapter = chapter
	current_choice_index = 0
	instability = 0.0
	is_unstable = false
	essence.clear()
	currency = 0
	injected_factors.clear()
	chapter_choices = _generate_chapter(chapter)
	EventBus.emit("run.started", {"chapter": chapter})
	EventBus.emit("run.essence_changed", essence.duplicate())
	EventBus.emit("run.instability_changed", instability)
	EventBus.emit("run.currency_changed", currency)

## 结束一局（死亡 / 通关）。
func end_run() -> void:
	is_running = false
	EventBus.emit("run.ended", {})

## ---- 章节 / 节点图 ----
func _generate_chapter(_chapter: int) -> Array:
	# M3 垂直切片：固定节点图（每阶段二选一，末段 Boss）。
	# 后续接入程序化生成 + 按章节配置怪物池。
	return [
		[{"type": "combat", "count": 3}, {"type": "event"}],
		[{"type": "combat", "count": 4}, {"type": "shop"}],
		[{"type": "rest"}, {"type": "combat", "count": 5}],
		[{"type": "combat", "count": 5}, {"type": "event"}],
		[{"type": "boss"}],
	]

## 当前阶段的可选房间列表。
func get_current_choices() -> Array:
	if current_choice_index < chapter_choices.size():
		return chapter_choices[current_choice_index]
	return []

## 选择某一项，推进到下一阶段，返回选中的房间。
func select_room(option_index: int) -> Dictionary:
	var choices := get_current_choices()
	if option_index < 0 or option_index >= choices.size():
		return {}
	current_choice_index += 1
	return choices[option_index]

func is_run_complete() -> bool:
	return current_choice_index >= chapter_choices.size()

func get_stage_progress() -> String:
	return "%d/%d" % [current_choice_index + 1, chapter_choices.size()]

## ---- 因子精华 ----
func gain_essence(factor_id: String) -> void:
	essence[factor_id] = get_essence(factor_id) + 1
	EventBus.emit("run.essence_changed", essence.duplicate())

func get_essence(factor_id: String) -> int:
	return int(essence.get(factor_id, 0))

## ---- 局内货币 ----
func gain_currency(amount: int) -> void:
	currency += amount
	EventBus.emit("run.currency_changed", currency)

func spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	EventBus.emit("run.currency_changed", currency)
	return true

## ---- 注射（核心风险收益入口） ----
func inject_factor(factor_id: String) -> void:
	if get_essence(factor_id) <= 0:
		return
	essence[factor_id] = get_essence(factor_id) - 1
	var factor := DataManager.get_factor(factor_id)
	if factor.is_empty():
		return
	injected_factors.append(factor_id)
	EventBus.emit("run.injected", {
		"factor_id": factor_id,
		"modifiers": factor.get("modifiers", []),
	})
	EventBus.emit("run.essence_changed", essence.duplicate())
	add_instability(float(factor.get("instability_gain", 0.0)))

## ---- 稳定剂 / 失控值 ----
func use_stabilizer() -> void:
	reduce_instability(STABILIZER_REDUCE)
	EventBus.emit("run.stabilizer_used", {})

func reduce_instability(amount: float) -> void:
	_change_instability(-amount)

func add_instability(amount: float) -> void:
	_change_instability(amount)

func _change_instability(delta: float) -> void:
	instability = clampf(instability + delta, 0.0, INSTABILITY_MAX)
	EventBus.emit("run.instability_changed", instability)
	var should_unstable := instability >= INSTABILITY_OVERFLOW_THRESHOLD
	if should_unstable != is_unstable:
		is_unstable = should_unstable
		EventBus.emit("run.unstable_state_changed", is_unstable)
