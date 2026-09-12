extends Node
## BuildManager —— 六边形情绪构筑系统（v0.2 重构核心）。
##
## 职责：
##  1. 管理 6 个环形槽位（编号 0~5，环上相邻：0-1、1-2、…、5-0）
##  2. 相邻检测 → 情绪共鸣（战栗 / 释然）；对立情绪共存 → 制衡第三属性
##  3. 乘法稀释：同类因子堆叠收益递减 dil = (1+n)^-0.3
##  4. 情绪污染：注射分布统计，单情绪占比 ≥60% 触发环境异变
##  5. 情绪过载：10s 内 ≥3 种不同共鸣/状态事件 → 触发无敌帧奖励
## 数据全部来自 DataManager（resonances / pollutions 表），代码只写规则。

const SLOT_COUNT := 6
const MAX_LEVEL := 5
const ADJACENT_PAIRS := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]
const OVERLOAD_WINDOW := 10.0
const OVERLOAD_KINDS := 3
const POLLUTION_RATIO := 0.6
const POLLUTION_MIN_INJECTIONS := 3

## 槽位：{factor_id: String, level: int}
var slots: Array[Dictionary] = []
## 注射分布统计：emotion -> 注射次数（用于情绪污染）
var injection_log: Dictionary = {}
## 情绪过载事件：{kind: String, time: float}
var _recent_events: Array = []

func _ready() -> void:
	reset_build()

func reset_build() -> void:
	slots.clear()
	for i in SLOT_COUNT:
		slots.append({"factor_id": "", "level": 0})
	injection_log.clear()
	_recent_events.clear()
	EventBus.emit("build.changed", {})

## ---- 槽位查询 ----
func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return slots[index]

func get_occupied() -> int:
	var n := 0
	for s in slots:
		if str(s["factor_id"]) != "":
			n += 1
	return n

func is_full() -> bool:
	return get_occupied() >= SLOT_COUNT

func get_total_levels() -> int:
	var n := 0
	for s in slots:
		n += int(s["level"])
	return n

func emotion_of_slot(index: int) -> String:
	var s := get_slot(index)
	if s.is_empty() or str(s["factor_id"]) == "":
		return ""
	var f := DataManager.get_factor(str(s["factor_id"]))
	return str(f.get("emotion", ""))

func emotion_count(emotion: String) -> int:
	var n := 0
	for i in SLOT_COUNT:
		if emotion_of_slot(i) == emotion:
			n += 1
	return n

func emotion_present(emotion: String) -> bool:
	return emotion_count(emotion) > 0

## ---- 乘法稀释：dil = (1 + 同类槽数)^-0.3 ----
func dilution(emotion: String) -> float:
	return pow(1.0 + float(emotion_count(emotion)), -0.3)

## ---- 因子放置 / 移除 ----
## 把因子放入指定槽位（同因子升级，异因子替换）。返回 {ok, level, replaced, factor_id}
func place_factor(slot_index: int, factor_id: String) -> Dictionary:
	var f := DataManager.get_factor(factor_id)
	if f.is_empty() or slot_index < 0 or slot_index >= SLOT_COUNT:
		return {"ok": false}
	var s: Dictionary = slots[slot_index]
	var replaced := ""
	if str(s["factor_id"]) == factor_id:
		s["level"] = mini(int(s["level"]) + 1, MAX_LEVEL)
	else:
		if str(s["factor_id"]) != "":
			replaced = str(s["factor_id"])
		s["factor_id"] = factor_id
		s["level"] = 1
	var emotion := str(f.get("emotion", factor_id))
	injection_log[emotion] = int(injection_log.get(emotion, 0)) + 1
	_after_change()
	return {"ok": true, "level": int(s["level"]), "replaced": replaced, "factor_id": factor_id}

## 直接放入（不进入注射统计）：用于局外「预设共鸣」开局。
func seed_factor(slot_index: int, factor_id: String) -> void:
	var f := DataManager.get_factor(factor_id)
	if f.is_empty() or slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	slots[slot_index] = {"factor_id": factor_id, "level": 1}
	_after_change()

## 情绪风暴代价：所有因子等级 -1，归零清槽。
func degrade_all() -> void:
	for s in slots:
		if str(s["factor_id"]) == "":
			continue
		s["level"] = int(s["level"]) - 1
		if int(s["level"]) <= 0:
			s["factor_id"] = ""
			s["level"] = 0
	_after_change()

## ---- 共鸣检测 ----
## 相邻共鸣：resonance_id -> 相邻对数
func get_adjacent_resonance_stacks() -> Dictionary:
	var result: Dictionary = {}
	var rows := DataManager.get_rows("resonances")
	for id in rows:
		var row: Dictionary = rows[id]
		if row.get("type", "") != "adjacent":
			continue
		var a := str(row.get("emotion_a", ""))
		var b := str(row.get("emotion_b", ""))
		var n := 0
		for pair in ADJACENT_PAIRS:
			var ea := emotion_of_slot(int(pair[0]))
			var eb := emotion_of_slot(int(pair[1]))
			if (ea == a and eb == b) or (ea == b and eb == a):
				n += 1
		if n > 0:
			result[id] = n
	return result

func get_resonance_stacks(resonance_id: String) -> int:
	return int(get_adjacent_resonance_stacks().get(resonance_id, 0))

## 对立制衡：两个对立情绪同环共存即激活。
func get_active_opposites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows := DataManager.get_rows("resonances")
	for id in rows:
		var row: Dictionary = rows[id]
		if row.get("type", "") != "opposite":
			continue
		if emotion_present(str(row.get("emotion_a", ""))) and emotion_present(str(row.get("emotion_b", ""))):
			out.append(row)
	return out

func has_opposite(oppose_id: String) -> bool:
	for row in get_active_opposites():
		if str(row.get("id", "")) == oppose_id:
			return true
	return false

## ---- 情绪污染 ----
## 返回当前主导污染 emotion（无则返回 ""）。
func dominant_pollution() -> String:
	var total := 0
	for k in injection_log:
		total += int(injection_log[k])
	if total < POLLUTION_MIN_INJECTIONS:
		return ""
	var rows := DataManager.get_rows("pollutions")
	for id in rows:
		var row: Dictionary = rows[id]
		var e := str(row.get("emotion", ""))
		if int(injection_log.get(e, 0)) * 100 >= int(POLLUTION_RATIO * 100.0) * total:
			return e
	return ""

func get_pollution_row(emotion: String) -> Dictionary:
	var rows := DataManager.get_rows("pollutions")
	for id in rows:
		var row: Dictionary = rows[id]
		if str(row.get("emotion", "")) == emotion:
			return row
	return {}

## ---- 情绪过载 ----
## 记录一种共鸣/状态事件；10s 内 ≥3 种不同事件 → 广播 build.overload。
func record_event(kind: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_recent_events.append({"kind": kind, "time": now})
	var kept: Array = []
	for ev in _recent_events:
		if now - float(ev["time"]) <= OVERLOAD_WINDOW:
			kept.append(ev)
	_recent_events = kept
	var kinds := {}
	for ev in _recent_events:
		kinds[str(ev["kind"])] = true
	if kinds.size() >= OVERLOAD_KINDS:
		_recent_events.clear()
		EventBus.emit("build.overload", {})

## ---- 词条同步 ----
## 按槽位重建玩家的 build 词条（等级 × 稀释），并同步稀释系数。
## mods 为玩家的 ModifierSystem。
func sync_mods(mods) -> void:
	var source := {}
	for s in slots:
		if str(s["factor_id"]) == "":
			continue
		var f := DataManager.get_factor(str(s["factor_id"]))
		if f.is_empty():
			continue
		var lvl := int(s["level"])
		for mid in f.get("modifiers", []):
			source[mid] = int(source.get(mid, 0)) + 1
		for mid in f.get("per_level_modifiers", []):
			source[mid] = int(source.get(mid, 0)) + lvl
	mods.set_source("build", source)
	mods.clear_mod_dilution()
	for s in slots:
		if str(s["factor_id"]) == "":
			continue
		var f := DataManager.get_factor(str(s["factor_id"]))
		if f.is_empty():
			continue
		var dil := dilution(str(f.get("emotion", "")))
		for mid in f.get("per_level_modifiers", []):
			mods.set_mod_dilution(str(mid), dil)

## ---- 内部 ----
func _after_change() -> void:
	EventBus.emit("build.changed", {})

## 判断一次放置是否产生了新的共鸣 / 对立（供 run.gd 记录情绪过载事件）。
func diff_events(before: Dictionary, before_opposites: Array) -> Array[String]:
	var kinds: Array[String] = []
	var after := get_adjacent_resonance_stacks()
	for id in after:
		if int(after[id]) != int(before.get(id, 0)):
			kinds.append("resonance")
			break
	var after_opp := get_active_opposites()
	var b_ids := {}
	for row in before_opposites:
		b_ids[str(row.get("id", ""))] = true
	for row in after_opp:
		if not b_ids.has(str(row.get("id", ""))):
			kinds.append("oppose")
			break
	return kinds
