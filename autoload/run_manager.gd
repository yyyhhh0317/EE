extends Node
## RunManager —— 单局运行状态：章节/关卡/精华/构筑/失控值。
## M2：因子精华收集、注射、失控值阈值与反噬、稳定剂。

const INSTABILITY_OVERFLOW_THRESHOLD := 60.0
const INSTABILITY_MAX := 100.0
const STABILIZER_REDUCE := 20.0

var is_running: bool = false
var current_chapter: int = 1
var current_level: int = 1

var instability: float = 0.0
var is_unstable: bool = false
var essence: Dictionary = {}  # factor_id -> int

var injected_factors: Array[String] = []

## 开始一局。
func start_run(chapter: int = 1) -> void:
	is_running = true
	current_chapter = chapter
	current_level = 1
	instability = 0.0
	is_unstable = false
	essence.clear()
	injected_factors.clear()
	EventBus.emit("run.started", {"chapter": chapter})
	EventBus.emit("run.essence_changed", essence.duplicate())
	EventBus.emit("run.instability_changed", instability)

## 结束一局（死亡 / 通关）。
func end_run() -> void:
	is_running = false
	EventBus.emit("run.ended", {})

## ---- 因子精华 ----
func gain_essence(factor_id: String) -> void:
	essence[factor_id] = get_essence(factor_id) + 1
	EventBus.emit("run.essence_changed", essence.duplicate())

func get_essence(factor_id: String) -> int:
	return int(essence.get(factor_id, 0))

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
	_change_instability(float(factor.get("instability_gain", 0.0)))

## ---- 稳定剂 ----
func use_stabilizer() -> void:
	_change_instability(-STABILIZER_REDUCE)
	EventBus.emit("run.stabilizer_used", {})

## ---- 失控值 ----
func _change_instability(delta: float) -> void:
	instability = clampf(instability + delta, 0.0, INSTABILITY_MAX)
	EventBus.emit("run.instability_changed", instability)
	var should_unstable := instability >= INSTABILITY_OVERFLOW_THRESHOLD
	if should_unstable != is_unstable:
		is_unstable = should_unstable
		EventBus.emit("run.unstable_state_changed", is_unstable)
