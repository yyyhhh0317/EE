extends Node
## MetaManager —— 局外成长（跨局持久）：核心货币 + 永久强化。
## 数据经 SaveManager 存到 user://meta.json。

const UPGRADES := [
	{"id": "max_hp", "name": "生命强化", "desc": "每级 +25 最大生命", "cost": 5, "max_level": 4},
	{"id": "start_currency", "name": "起始结晶", "desc": "每级 +30 起始结晶", "cost": 6, "max_level": 3},
	{"id": "start_rage", "name": "起始怒精华", "desc": "每级 +1 起始怒精华", "cost": 8, "max_level": 2},
]

var cores: int = 0
var upgrades: Dictionary = {}  # upgrade_id -> level

func _ready() -> void:
	load_from_save()

func load_from_save() -> void:
	var data := SaveManager.load_meta()
	cores = int(data.get("cores", 0))
	upgrades = data.get("upgrades", {})

func save() -> void:
	SaveManager.save_meta({"cores": cores, "upgrades": upgrades})

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
