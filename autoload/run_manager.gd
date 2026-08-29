extends Node
## RunManager —— 单局（Run）运行状态：章节/关卡/构筑/失控值。
## 因子注射与失控值是核心循环，M2 完整实现，当前为骨架。

var is_running: bool = false
var current_chapter: int = 1
var current_level: int = 1
var instability: float = 0.0  # 失控值

var injected_factors: Array[String] = []  # 已注射的因子 id
var inventory: Array[String] = []         # 持有的词条/技能 id

## 开始一局。
func start_run(chapter: int = 1) -> void:
	is_running = true
	current_chapter = chapter
	current_level = 1
	instability = 0.0
	injected_factors.clear()
	inventory.clear()
	EventBus.emit("run.started", {"chapter": chapter})

## 结束一局（死亡 / 通关）。
func end_run() -> void:
	is_running = false
	EventBus.emit("run.ended", {})

## 注射因子：核心风险收益入口。
func inject_factor(factor_id: String) -> void:
	var factor: Dictionary = DataManager.get_factor(factor_id)
	if factor.is_empty():
		push_warning("RunManager: 未知因子 %s" % factor_id)
		return
	injected_factors.append(factor_id)
	instability += float(factor.get("instability_gain", 0.0))
	EventBus.emit("run.instability_changed", instability)

## 降低失控值（稳定剂）。
func reduce_instability(amount: float) -> void:
	instability = maxf(0.0, instability - amount)
	EventBus.emit("run.instability_changed", instability)
