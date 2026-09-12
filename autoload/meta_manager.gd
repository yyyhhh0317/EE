extends Node
## MetaManager —— 局外成长（跨局持久）：核心货币 + 永久强化 + 记忆碎片系统（v0.2）。
## 记忆碎片：死亡/通关结算获得，用于「禁用因子」（降方差）与「预设初级共鸣」（定开局）。
## 数据经 SaveManager 存到 user://meta.json。

const UPGRADES := [
	{"id": "max_hp", "name": "生命强化", "desc": "每级 +25 最大生命", "cost": 5, "max_level": 4},
	{"id": "attack", "name": "攻击强化", "desc": "每级 +3 攻击", "cost": 6, "max_level": 4},
	{"id": "move_speed", "name": "移速强化", "desc": "每级 +6% 移速", "cost": 6, "max_level": 4},
	{"id": "start_currency", "name": "起始结晶", "desc": "每级 +30 起始结晶", "cost": 6, "max_level": 3},
	{"id": "start_rage", "name": "起始怒精华", "desc": "每级 +1 起始怒精华", "cost": 8, "max_level": 2},
	{"id": "start_fear", "name": "起始惧精华", "desc": "每级 +1 起始惧精华", "cost": 8, "max_level": 2},
	{"id": "sanity_regen", "name": "理智回复", "desc": "每级 +1/s 理智回复", "cost": 7, "max_level": 3},
]

## ---- 记忆碎片系统 ----
const BAN_COST := 30
const PRESET_COST := 50
const MAX_BANS := 2
const BANNABLE := ["factor_rage", "factor_fear", "factor_joy", "factor_sorrow"]
const PRESETS := {"": "无", "rage_fear": "战栗（怒+惧）", "joy_sorrow": "释然（喜+哀）"}

var cores: int = 0
var upgrades: Dictionary = {}  # upgrade_id -> level
var shards: int = 0
var banned_factors: Array = []  # factor_id
var preset: String = ""         # "" / "rage_fear" / "joy_sorrow"

func _ready() -> void:
	load_from_save()

func load_from_save() -> void:
	var data := SaveManager.load_meta()
	cores = int(data.get("cores", 0))
	upgrades = data.get("upgrades", {})
	shards = int(data.get("shards", 0))
	banned_factors = data.get("banned_factors", [])
	preset = str(data.get("preset", ""))

func save() -> void:
	SaveManager.save_meta({
		"cores": cores,
		"upgrades": upgrades,
		"shards": shards,
		"banned_factors": banned_factors,
		"preset": preset,
	})

## ---- 核心货币 / 永久强化 ----
func get_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))

func get_upgrade(upgrade_id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == upgrade_id:
			return u
	return {}

## 返回升级费用；-1 表示已满级或不存在。
func get_upgrade_cost(upgrade_id: String) -> int:
	var def := get_upgrade(upgrade_id)
	if def.is_empty():
		return -1
	if get_level(upgrade_id) >= int(def.get("max_level", 1)):
		return -1
	return int(def.get("cost", 5))

func buy_upgrade(upgrade_id: String) -> bool:
	var cost := get_upgrade_cost(upgrade_id)
	if cost < 0 or cores < cost:
		return false
	cores -= cost
	upgrades[upgrade_id] = get_level(upgrade_id) + 1
	save()
	EventBus.emit("meta.changed", {})
	return true

func add_cores(amount: int) -> void:
	cores += amount
	save()

## ---- 记忆碎片 ----
func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	shards += amount
	save()
	EventBus.emit("meta.changed", {})

func spend_shards(amount: int) -> bool:
	if shards < amount:
		return false
	shards -= amount
	save()
	EventBus.emit("meta.changed", {})
	return true

## ---- 禁用因子（可再按一次解禁并退款） ----
func is_banned(factor_id: String) -> bool:
	return factor_id in banned_factors

func get_ban_count() -> int:
	return banned_factors.size()

## 切换禁/解禁。返回结果文本给 UI。
func toggle_ban(factor_id: String) -> Dictionary:
	if not factor_id in BANNABLE:
		return {"ok": false, "text": "该因子不可禁用"}
	if is_banned(factor_id):
		banned_factors.erase(factor_id)
		add_shards(BAN_COST)
		save()
		EventBus.emit("meta.changed", {})
		return {"ok": true, "text": "已解禁，退还 %d 碎片" % BAN_COST}
	if get_ban_count() >= MAX_BANS:
		return {"ok": false, "text": "最多禁用 %d 个因子" % MAX_BANS}
	if not spend_shards(BAN_COST):
		return {"ok": false, "text": "碎片不足（需要 %d）" % BAN_COST}
	banned_factors.append(factor_id)
	save()
	EventBus.emit("meta.changed", {})
	return {"ok": true, "text": "已禁用，局内不再掉落该因子"}

## ---- 预设初级共鸣 ----
func get_preset() -> String:
	return preset

## 切换预设（未解锁时花费碎片解锁）。返回结果文本。
func toggle_preset() -> Dictionary:
	if preset != "":
		preset = ""
		save()
		EventBus.emit("meta.changed", {})
		return {"ok": true, "text": "已取消预设共鸣"}
	if shards < PRESET_COST:
		return {"ok": false, "text": "碎片不足（需要 %d）" % PRESET_COST}
	shards -= PRESET_COST
	preset = "rage_fear"
	save()
	EventBus.emit("meta.changed", {})
	return {"ok": true, "text": "已解锁：开局自带战栗共鸣（怒+惧相邻）"}

## 循环切换已解锁的预设类型。
func cycle_preset() -> Dictionary:
	if preset == "":
		return toggle_preset()
	if preset == "rage_fear":
		preset = "joy_sorrow"
		save()
		EventBus.emit("meta.changed", {})
		return {"ok": true, "text": "已切换：开局自带释然共鸣（喜+哀相邻）"}
	preset = ""
	save()
	EventBus.emit("meta.changed", {})
	return {"ok": true, "text": "已取消预设共鸣"}
