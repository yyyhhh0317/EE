extends Node
## RunManager —— 单局运行状态（v0.2 重构）：
## 双轨资源（理智/失控）+ 临界状态机（稳定/亢奋/暴走/冷却）+ 动态难度 + 记忆碎片。
## 也保留 M3/M4 职责：章节/房间/精华/货币/种子/难度。

## ---- 双轨资源常量 ----
const SANITY_MAX := 100.0
const OVERHEAT_MAX := 100.0
const EXCITE_THRESHOLD := 0.7            # 亢奋阈值（对立制衡「躁动」可降至 0.6）
const OVERHEAT_DECAY := 6.0              # 失控自然衰减 /s
const OVERHEAT_DECAY_IDLE := 12.0        # 停火停受伤 2s 后衰减翻倍
const SANITY_REGEN_BASE := 8.0           # 理智基础回复 /s
const DASH_SANITY_COST := 15.0           # 冲刺理智消耗
const ATTACK_OVERHEAT := 1.2             # 普攻失控增量
const DAMAGED_OVERHEAT := 8.0            # 受击失控增量
const BERSERK_SANITY_DRAIN := 18.0       # 暴走吞噬理智 /s（满理智进入可存活，低理智=自毁）
const BERSERK_OVERHEAT_DECAY := 25.0     # 暴走失控回落 /s（比理智吞噬快，暴走可结束）
const BERSERK_COOLDOWN := 10.0           # 暴走回落冷却
const EXCITED_HP_DRAIN := 4.0            # 亢奋持续扣血 /s
const ULTIMATE_COOLDOWN := 25.0          # 情绪风暴冷却
const ULTIMATE_SANITY_COST := 60.0       # 情绪风暴理智消耗
const ULTIMATE_OVERHEAT_GAIN := 40.0     # 情绪风暴失控代价
const STABILIZER_REDUCE := 20.0
const REST_INSTABILITY_REDUCE := 25.0
const REST_SANITY_HEAL := 25.0

## 兼容旧 API（M2 的「失控值」已并入双轨资源）。
const INSTABILITY_OVERFLOW_THRESHOLD := 70.0
const INSTABILITY_MAX := OVERHEAT_MAX

enum State { STABLE, EXCITED, BERSERK, COOLDOWN }
const STATE_NAMES := ["稳定", "亢奋", "暴走", "冷却"]

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

## ---- 双轨资源 ----
var sanity: float = SANITY_MAX
var overheat: float = 0.0
var state: State = State.STABLE
var ultimate_cd: float = 0.0

var _berserk_cooldown: float = 0.0
var _since_attack: float = 999.0
var _since_damaged: float = 999.0

## ---- 局内资源 ----
var essence: Dictionary = {}  # factor_id -> int
var currency: int = 0
var kills: int = 0

var _player_ref: Node = null

## 兼容旧 API：旧代码读取 RunManager.instability。
var instability: float:
	get: return overheat
var is_unstable: bool:
	get: return state == State.EXCITED or state == State.BERSERK

## 开始一局（可指定种子，0 = 随机）。
func start_run(chapter: int = 1, seed_override: int = 0) -> void:
	is_running = true
	current_chapter = chapter
	current_choice_index = 0
	sanity = SANITY_MAX
	overheat = 0.0
	state = State.STABLE
	ultimate_cd = 0.0
	_berserk_cooldown = 0.0
	_since_attack = 999.0
	_since_damaged = 999.0
	essence.clear()
	currency = 0
	kills = 0
	BuildManager.reset_build()
	# 种子
	seed = seed_override if seed_override != 0 else randi()
	_rng.seed = seed
	chapter_choices = _generate_chapter(chapter)
	# 局外成长：预设共鸣开局（占相邻 0/1 槽，不消耗精华、不计数污染）
	var preset := MetaManager.get_preset()
	if preset == "rage_fear":
		BuildManager.seed_factor(0, "factor_rage")
		BuildManager.seed_factor(1, "factor_fear")
	elif preset == "joy_sorrow":
		BuildManager.seed_factor(0, "factor_joy")
		BuildManager.seed_factor(1, "factor_sorrow")
	EventBus.emit("run.started", {"chapter": chapter, "seed": seed})
	EventBus.emit("run.essence_changed", essence.duplicate())
	EventBus.emit("run.overheat_changed", overheat)
	EventBus.emit("run.sanity_changed", sanity)
	EventBus.emit("run.instability_changed", overheat)  # 兼容旧事件
	EventBus.emit("run.currency_changed", currency)

## 结束一局：结算记忆碎片（死亡/通关），并写回 Meta。
func end_run(victory: bool = false) -> void:
	if not is_running:
		return
	is_running = false
	var shards := shards_on_victory() if victory else shards_on_death()
	MetaManager.add_shards(shards)
	EventBus.emit("run.ended", {"victory": victory, "shards": shards})

## ---- 双轨资源 tick（由玩家每帧驱动） ----
func tick(delta: float, mods) -> void:
	_since_attack += delta
	_since_damaged += delta
	_berserk_cooldown = maxf(0.0, _berserk_cooldown - delta)
	ultimate_cd = maxf(0.0, ultimate_cd - delta)
	match state:
		State.STABLE, State.EXCITED, State.COOLDOWN:
			var idle := _since_attack > 2.0 and _since_damaged > 2.0
			var decay := OVERHEAT_DECAY * (2.0 if idle else 1.0) * calm_decay_mult()
			overheat = maxf(0.0, overheat - decay * delta)
			if state == State.COOLDOWN:
				if _berserk_cooldown <= 0.0 and overheat < OVERHEAT_MAX:
					_set_state(State.STABLE)
			elif overheat >= OVERHEAT_MAX:
				_enter_berserk()
			elif overheat >= OVERHEAT_MAX * excite_threshold():
				_set_state(State.EXCITED)
			else:
				_set_state(State.STABLE)
		State.BERSERK:
			sanity -= BERSERK_SANITY_DRAIN * delta
			overheat -= BERSERK_OVERHEAT_DECAY * delta
			if sanity <= 0.0:
				sanity = 0.0
				overheat = maxf(0.0, overheat)
				_set_state(State.STABLE)
				EventBus.emit("run.sanity_depleted", {})
				return
			if overheat <= 0.0:
				overheat = 0.0
				_set_state(State.COOLDOWN)
				_berserk_cooldown = BERSERK_COOLDOWN
	# 理智回复（暴走中不回复）
	if state != State.BERSERK:
		var regen := SANITY_REGEN_BASE + MetaManager.get_level("sanity_regen") * 1.0
		if mods != null:
			regen = mods.get_stat(regen, "sanity_regen")
		sanity = minf(SANITY_MAX, sanity + regen * delta)

func calm_decay_mult() -> float:
	return 1.0 + float(BuildManager.get_resonance_stacks("resonance_joy_sorrow"))

func excite_threshold() -> float:
	if BuildManager.has_opposite("oppose_rage_joy"):
		return 0.6
	return EXCITE_THRESHOLD

func damage_overheat_mult() -> float:
	if BuildManager.has_opposite("oppose_fear_sorrow"):
		return 0.5
	return 1.0

func get_state_name() -> String:
	return STATE_NAMES[int(state)]

## ---- 失控值增减 ----
func add_overheat(amount: float) -> void:
	overheat = clampf(overheat + amount, 0.0, OVERHEAT_MAX)
	if overheat >= OVERHEAT_MAX and (state == State.STABLE or state == State.EXCITED or (state == State.COOLDOWN and _berserk_cooldown <= 0.0)):
		_enter_berserk()
	elif overheat >= OVERHEAT_MAX * excite_threshold() and state == State.STABLE:
		_set_state(State.EXCITED)
	EventBus.emit("run.overheat_changed", overheat)
	EventBus.emit("run.instability_changed", overheat)  # 兼容旧事件

func reduce_overheat(amount: float) -> void:
	overheat = clampf(overheat - amount, 0.0, OVERHEAT_MAX)
	EventBus.emit("run.overheat_changed", overheat)
	EventBus.emit("run.instability_changed", overheat)  # 兼容旧事件

## 兼容旧 API。
func add_instability(amount: float) -> void:
	add_overheat(amount)

func reduce_instability(amount: float) -> void:
	reduce_overheat(amount)

func use_stabilizer() -> void:
	reduce_overheat(STABILIZER_REDUCE)
	EventBus.emit("run.stabilizer_used", {})

## ---- 理智 ----
func spend_sanity(cost: float) -> bool:
	if sanity < cost:
		return false
	sanity -= cost
	EventBus.emit("run.sanity_changed", sanity)
	return true

func add_sanity(amount: float) -> void:
	sanity = clampf(sanity + amount, 0.0, SANITY_MAX)
	EventBus.emit("run.sanity_changed", sanity)

## ---- 战斗事件记账（失控增量来源） ----
func register_attack() -> void:
	_since_attack = 0.0
	if state != State.BERSERK:
		add_overheat(ATTACK_OVERHEAT)

func register_damaged() -> void:
	_since_damaged = 0.0
	add_overheat(DAMAGED_OVERHEAT * damage_overheat_mult())

func register_kill() -> void:
	kills += 1

## ---- 状态机内部 ----
func _enter_berserk() -> void:
	BuildManager.record_event("berserk")
	_set_state(State.BERSERK)

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	var from := state
	state = new_state
	EventBus.emit("run.state_changed", {"from": int(from), "to": int(new_state)})
	EventBus.emit("run.unstable_state_changed", is_unstable)  # 兼容旧事件

## ---- 动态难度（自适应当前强度） ----
func set_player_ref(player: Node) -> void:
	_player_ref = player

func enemy_damage_mult() -> float:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return 1.0
	var atk: float = _player_ref.get_effective_attack()
	var fire_rate: float = maxf(0.01, _player_ref.get_effective_fire_rate())
	var weight := atk * (1.0 / fire_rate) * (1.0 + 0.15 * float(BuildManager.get_occupied()))
	var env_base := 14.0 + 3.0 * float(current_choice_index)
	return 1.0 + (weight / maxf(1.0, env_base)) * 0.4

## ---- 情绪风暴（共振回路大招） ----
func can_ultimate() -> bool:
	return ultimate_cd <= 0.0 and BuildManager.is_full()

func use_ultimate() -> void:
	ultimate_cd = ULTIMATE_COOLDOWN

## ---- 记忆碎片 ----
func shards_on_death() -> int:
	return 5 + current_choice_index * 2

func shards_on_victory() -> int:
	return 20 + int(float(kills) * 0.1)

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
## 被局外禁用的因子不会入账，自动折算为 10 结晶。
func gain_essence(factor_id: String) -> void:
	if MetaManager.is_banned(factor_id):
		gain_currency(10)
		return
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

## ---- 注射（核心风险收益入口）：选槽放置 + 失控代价 ----
func inject_factor(factor_id: String, slot: int = -1) -> Dictionary:
	if get_essence(factor_id) <= 0:
		return {"ok": false, "reason": "no_essence"}
	var factor := DataManager.get_factor(factor_id)
	if factor.is_empty():
		return {"ok": false, "reason": "unknown"}
	if slot < 0:
		slot = _first_empty_slot()
		if slot < 0:
			return {"ok": false, "reason": "full"}
	var res := BuildManager.place_factor(slot, factor_id)
	if not bool(res.get("ok", false)):
		return {"ok": false, "reason": "slot"}
	essence[factor_id] = get_essence(factor_id) - 1
	EventBus.emit("run.essence_changed", essence.duplicate())
	EventBus.emit("run.injected", {
		"factor_id": factor_id,
		"slot": slot,
		"level": res.get("level", 1),
		"replaced": res.get("replaced", ""),
		"modifiers": factor.get("modifiers", []),
		"per_level_modifiers": factor.get("per_level_modifiers", []),
	})
	add_overheat(float(factor.get("instability_gain", 10.0)) * get_difficulty_mult("instability"))
	return {"ok": true, "slot": slot, "level": res.get("level", 1)}

func _first_empty_slot() -> int:
	for i in BuildManager.SLOT_COUNT:
		if str(BuildManager.get_slot(i).get("factor_id", "")) == "":
			return i
	return -1
