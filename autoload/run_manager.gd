extends Node
## RunManager —— 单局运行状态：章节/房间/精华/货币/构筑/失控值/种子/难度。
## M4：种子化随机 + 难度层级；M3：节点图推进 + 货币；M2：注射/失控值。

const INSTABILITY_OVERFLOW_THRESHOLD := 60.0
const INSTABILITY_MAX := 100.0
const STABILIZER_REDUCE := 20.0
const REST_INSTABILITY_REDUCE := 25.0

const DIFFICULTIES := [
	{"name": "普通", "hp": 1.0, "damage": 1.0, "instability": 1.0},
	{"name": "困难", "hp": 1.4, "damage": 1.3, "instability": 1.2},
	{"name": "噩梦", "hp": 1.8, "damage": 1.6, "instability": 1.4},
]

var is_running: bool = false
var current_chapter: int = 1
var current_choice_index: int = 0
var chapter_choices: Array = []  # [ [room, room], ..., [boss] ]

var seed: int = 0
var difficulty: int = 0
var _rng := RandomNumberGenerator.new()

var instability: float = 0.0
var instability_threshold: float = INSTABILITY_OVERFLOW_THRESHOLD
var is_unstable: bool = false
var essence: Dictionary = {}  # factor_id -> int
var currency: int = 0

var injected_factors: Array[String] = []

## 开始一局（可指定种子，0 = 随机）。
func start_run(chapter: int = 1, seed_override: int = 0) -> void:
	is_running = true
	current_chapter = chapter
	current_choice_index = 0
	instability = 0.0
	is_unstable = false
	essence.clear()
	currency = 0
	injected_factors.clear()
	# 种子
	seed = seed_override if seed_override != 0 else randi()
	_rng.seed = seed
	# 失控阈值（含 meta 抗性加成）
	instability_threshold = INSTABILITY_OVERFLOW_THRESHOLD + MetaManager.get_level("instability_resist") * 15.0
	chapter_choices = _generate_chapter(chapter)
	EventBus.emit("run.started", {"chapter": chapter, "seed": seed})
	EventBus.emit("run.essence_changed", essence.duplicate())
	EventBus.emit("run.instability_changed", instability)
	EventBus.emit("run.currency_changed", currency)

## 结束一局（死亡 / 通关）。
func end_run() -> void:
	is_running = false
	EventBus.emit("run.ended", {})

## ---- 章节 / 节点图 ----
func _generate_chapter(_chapter: int) -> Array:
	# M4：结构固定，怪物数量由种子随机（后续换成完整程序化节点图）。
	return [
		[{"type": "combat", "count": rng_randi_range(2, 4)}, {"type": "event"}],
		[{"type": "combat", "count": rng_randi_range(3, 5)}, {"type": "shop"}],
		[{"type": "rest"}, {"type": "combat", "count": rng_randi_range(4, 6)}],
		[{"type": "combat", "count": rng_randi_range(4, 6)}, {"type": "event"}],
		[{"type": "boss"}],
	]

func get_current_choices() -> Array:
	if current_choice_index < chapter_choices.size():
		return chapter_choices[current_choice_index]
	return []

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

## ---- 种子随机 ----
func rng_randf() -> float:
	return _rng.randf()

func rng_randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)

func rng_randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

## ---- 难度 ----
func cycle_difficulty() -> void:
	difficulty = (difficulty + 1) % DIFFICULTIES.size()

func get_difficulty_name() -> String:
	return DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)]["name"]

func get_difficulty_mult(key: String) -> float:
	var d: Dictionary = DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)]
	return float(d.get(key, 1.0))

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
	var gain := float(factor.get("instability_gain", 0.0)) * get_difficulty_mult("instability")
	add_instability(gain)

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
	var should_unstable := instability >= instability_threshold
	if should_unstable != is_unstable:
		is_unstable = should_unstable
		EventBus.emit("run.unstable_state_changed", is_unstable)
