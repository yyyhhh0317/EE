extends Node2D
## Run —— 单局场景：持久持有玩家与 HUD，按房间切换 RoomContainer 内容。
## 房间类型：combat / rest / shop / event / boss；节点图二选一 + 章节首尾剧情。

enum RunState { TITLE, STORY_OPEN, CHOICE, ROOM, CLEARED, STORY_CLOSE, VICTORY }

const BASIC_ENEMY_SCENE := preload("res://enemies/basic_enemy.tscn")
const BOSS_ENEMY_SCENE := preload("res://enemies/boss_enemy.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://combat/damage_number.tscn")
const PICKUP_SCENE := preload("res://combat/pickup.tscn")

const SHOP_ITEMS := [
	{"name": "恢复 30 HP", "price": 15, "effect": "heal30"},
	{"name": "稳定剂（-20 失控）", "price": 20, "effect": "stabilizer"},
	{"name": "怒精华 ×1", "price": 25, "effect": "essence_rage"},
	{"name": "惧精华 ×1", "price": 25, "effect": "essence_fear"},
]

const EVENTS := [
	{
		"title": "未标记的药剂",
		"text": "废墟里躺着一瓶未标记的药剂，\n标签模糊地写着『情绪因子』。",
		"options": [
			{"text": "喝下它", "effect": "drink"},
			{"text": "丢弃", "effect": "discard"},
		],
	},
	{
		"title": "失控的实验终端",
		"text": "一台仍在运转的因子提取终端，\n屏幕闪烁着刺眼的红色警告。",
		"options": [
			{"text": "强行提取因子", "effect": "extract"},
			{"text": "稳妥关闭", "effect": "shutdown"},
		],
	},
]

const STORY_OPENING := "第 1 章 · 暴怒\n\n这片区域的生物被过量注射了『暴怒因子』，\n变得狂暴嗜血、无差别攻击一切。\n\n作为零号受试者，清理失控体、回收因子精华，\n查明失控实验背后的真相。"
const STORY_CLOSING := "你击败了狂暴巨人，暴怒因子的源头暂时平息。\n\n但实验室的更深处，还有更多情绪在失控……"

@onready var room_container: Node2D = $RoomContainer
@onready var fx_layer: Node2D = $FxLayer
@onready var player: Player = $Player
@onready var hp_label: Label = $UILayer/HUD/HP
@onready var instability_label: Label = $UILayer/HUD/InstabilityLabel
@onready var instability_bar: ProgressBar = $UILayer/HUD/InstabilityBar
@onready var essence_label: Label = $UILayer/HUD/EssenceLabel
@onready var status_label: Label = $UILayer/HUD/StatusLabel
@onready var unstable_warning: Label = $UILayer/HUD/UnstableWarning
@onready var currency_label: Label = $UILayer/HUD/CurrencyLabel
@onready var room_progress_label: Label = $UILayer/HUD/RoomProgress
@onready var interact_prompt: Label = $UILayer/HUD/InteractPrompt
@onready var chapter_title: Label = $UILayer/HUD/ChapterTitle
@onready var victory_panel: ColorRect = $UILayer/HUD/VictoryPanel
@onready var victory_label: Label = $UILayer/HUD/VictoryPanel/VictoryLabel
@onready var overlay_panel: ColorRect = $UILayer/HUD/OverlayPanel
@onready var overlay_title: Label = $UILayer/HUD/OverlayPanel/OverlayTitle
@onready var overlay_body: Label = $UILayer/HUD/OverlayPanel/OverlayBody

var run_state: RunState = RunState.TITLE
var _enemies_alive: int = 0
var _selected_room: Dictionary = {}
var _current_event: Dictionary = {}

func _ready() -> void:
	print("[Run] 单局开始（M3 完整切片）。")
	EventBus.on("combat.damage_dealt", _on_damage_dealt)
	EventBus.on("combat.entity_died", _on_entity_died)
	EventBus.on("player.hp_changed", _on_player_hp_changed)
	EventBus.on("run.instability_changed", _on_instability_changed)
	EventBus.on("run.essence_changed", _on_essence_changed)
	EventBus.on("run.unstable_state_changed", _on_unstable_state_changed)
	EventBus.on("run.currency_changed", _on_currency_changed)
	_on_instability_changed(RunManager.instability)
	_on_essence_changed(RunManager.essence)
	_on_unstable_state_changed(RunManager.is_unstable)
	_on_currency_changed(RunManager.currency)
	_show_chapter_title()

func _process(_delta: float) -> void:
	_update_status()

## ---- 流程状态机 ----
func _show_chapter_title() -> void:
	chapter_title.text = "第 %d 章 · 暴怒因子" % RunManager.current_chapter
	chapter_title.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(chapter_title, "modulate", Color(1, 1, 1, 1), 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(chapter_title, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(_enter_story_open)

func _enter_story_open() -> void:
	_set_player_active(false)
	run_state = RunState.STORY_OPEN
	_show_overlay("", STORY_OPENING + "\n\n按 E 继续")

func _enter_choice() -> void:
	overlay_panel.visible = false
	var choices := RunManager.get_current_choices()
	if choices.size() == 1:
		_select_room(0)
		return
	_set_player_active(false)
	run_state = RunState.CHOICE
	var body := "1. %s\n2. %s\n\n按 1 或 2 选择" % [_room_label(choices[0]), _room_label(choices[1])]
	_show_overlay("选择前进方向", body)

func _select_room(option_index: int) -> void:
	var room := RunManager.select_room(option_index)
	if room.is_empty():
		return
	overlay_panel.visible = false
	_selected_room = room
	_load_room(room)

func _load_room(room: Dictionary) -> void:
	run_state = RunState.ROOM
	_clear_room()
	interact_prompt.visible = false
	var is_combat: bool = room.get("type", "") in ["combat", "boss"]
	_set_player_active(is_combat)
	match room.get("type", ""):
		"combat":
			_spawn_combat(int(room.get("count", 4)))
		"boss":
			_spawn_boss()
		"rest":
			_enter_rest()
		"shop":
			_enter_shop()
		"event":
			_enter_event()
	room_progress_label.text = "阶段 %s" % RunManager.get_stage_progress()

func _room_cleared() -> void:
	overlay_panel.visible = false
	run_state = RunState.CLEARED
	interact_prompt.text = "按 E 进入下一关"
	interact_prompt.visible = true

func _enter_story_close() -> void:
	_set_player_active(false)
	run_state = RunState.STORY_CLOSE
	_show_overlay("", STORY_CLOSING + "\n\n按 E 继续")

func _on_victory() -> void:
	overlay_panel.visible = false
	victory_label.text = "第 %d 章通关！" % RunManager.current_chapter
	victory_panel.visible = true
	run_state = RunState.VICTORY
	_set_player_active(false)

## ---- 房间内容 ----
func _clear_room() -> void:
	for c in room_container.get_children():
		c.queue_free()
	for c in fx_layer.get_children():
		c.queue_free()
	_enemies_alive = 0

func _spawn_combat(count: int) -> void:
	for i in count:
		_spawn_enemy()

func _spawn_enemy() -> void:
	var e: BasicEnemy = BASIC_ENEMY_SCENE.instantiate()
	room_container.add_child(e)
	var angle := randf() * TAU
	var dist := randf_range(160.0, 260.0)
	e.global_position = player.global_position + Vector2.from_angle(angle) * dist
	_enemies_alive += 1

func _spawn_boss() -> void:
	var b: BossEnemy = BOSS_ENEMY_SCENE.instantiate()
	room_container.add_child(b)
	b.global_position = player.global_position + Vector2(0, 200)

func _enter_rest() -> void:
	interact_prompt.text = "休息房 · 按 E 恢复生命并降低失控值"
	interact_prompt.visible = true

func _enter_shop() -> void:
	_show_shop()

func _enter_event() -> void:
	_current_event = EVENTS[randi() % EVENTS.size()]
	_show_event(_current_event)

## ---- 商店 / 事件 ----
func _show_shop() -> void:
	var lines: Array = []
	for i in SHOP_ITEMS.size():
		lines.append("%d. %s — %d 结晶" % [i + 1, SHOP_ITEMS[i]["name"], SHOP_ITEMS[i]["price"]])
	var body := "\n".join(lines) + "\n\n按 1-%d 购买 · E 离开" % SHOP_ITEMS.size()
	_show_overlay("商店（结晶 ×%d）" % RunManager.currency, body)

func _buy_item(index: int) -> void:
	if index < 0 or index >= SHOP_ITEMS.size():
		return
	var item: Dictionary = SHOP_ITEMS[index]
	if RunManager.spend_currency(int(item["price"])):
		_apply_effect(str(item["effect"]))
	_show_shop()

func _show_event(ev: Dictionary) -> void:
	var lines: Array = [ev["text"], ""]
	var options: Array = ev["options"]
	for i in options.size():
		lines.append("%d. %s" % [i + 1, options[i]["text"]])
	_show_overlay(str(ev["title"]), "\n".join(lines) + "\n\n按 1 或 2 选择")

func _choose_event(option_index: int) -> void:
	var options: Array = _current_event.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return
	_apply_effect(str(options[option_index]["effect"]))
	_room_cleared()

## ---- 效果 ----
func _apply_effect(effect: String) -> void:
	match effect:
		"heal30":
			player.heal(30.0)
		"stabilizer":
			RunManager.use_stabilizer()
		"essence_rage":
			RunManager.gain_essence("factor_rage")
		"essence_fear":
			RunManager.gain_essence("factor_fear")
		"drink":
			player.heal(30.0)
			RunManager.add_instability(10.0)
		"discard":
			RunManager.gain_currency(15)
		"extract":
			RunManager.gain_essence("factor_rage")
			RunManager.add_instability(15.0)
		"shutdown":
			RunManager.reduce_instability(10.0)

## ---- 交互 ----
func _do_rest() -> void:
	player.heal(40.0)
	RunManager.reduce_instability(RunManager.REST_INSTABILITY_REDUCE)
	_room_cleared()

## ---- 事件回调 ----
func _on_damage_dealt(payload: Dictionary) -> void:
	var target: Node = payload.get("target")
	var amount: float = payload.get("amount", 0.0)
	if not is_instance_valid(target):
		return
	var color := Color(1.0, 0.35, 0.35) if target.is_in_group("player") else Color(1.0, 0.95, 0.5)
	var num: Label = DAMAGE_NUMBER_SCENE.instantiate()
	fx_layer.add_child(num)
	num.setup(amount, target.global_position, color)

func _on_entity_died(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.is_in_group("boss"):
		_enter_story_close()
		return
	RunManager.gain_currency(randi_range(3, 6))
	var pos: Vector2 = enemy.global_position
	_spawn_drop.call_deferred(pos)
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_room_cleared()

func _spawn_drop(pos: Vector2) -> void:
	var roll := randf()
	var type := "factor_rage"
	if roll < 0.4:
		type = "factor_rage"
	elif roll < 0.8:
		type = "factor_fear"
	else:
		type = "stabilizer"
	var p: Pickup = PICKUP_SCENE.instantiate()
	fx_layer.add_child(p)
	p.setup(type, pos)

func _on_player_hp_changed(hp: float) -> void:
	hp_label.text = "HP: %d/%d" % [int(hp), int(player.health.max_hp)]

func _on_instability_changed(value: float) -> void:
	instability_bar.value = value
	instability_label.text = "失控值 %d/%d" % [int(value), int(RunManager.INSTABILITY_MAX)]

func _on_essence_changed(ess: Dictionary) -> void:
	essence_label.text = "怒精华 ×%d   惧精华 ×%d" % [
		int(ess.get("factor_rage", 0)), int(ess.get("factor_fear", 0)),
	]

func _on_unstable_state_changed(unstable: bool) -> void:
	unstable_warning.visible = unstable

func _on_currency_changed(value: int) -> void:
	currency_label.text = "结晶 ×%d" % value

func _update_status() -> void:
	if not is_instance_valid(player):
		return
	var rage := player.mods.get_stacks("mod_rage_stack")
	var fear := player.mods.get_stacks("mod_fear_speed")
	status_label.text = "怒叠层 %d · 惧叠层 %d · 攻击 %.0f · 移速 %.0f" % [
		rage, fear, player.get_effective_attack(), player.get_effective_move_speed(),
	]

## ---- 输入 ----
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameManager.back_to_menu()
		return
	match run_state:
		RunState.TITLE:
			pass
		RunState.STORY_OPEN:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_enter_choice()
		RunState.STORY_CLOSE:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_on_victory()
		RunState.CHOICE:
			if _key(event, KEY_1):
				get_viewport().set_input_as_handled()
				_select_room(0)
			elif _key(event, KEY_2):
				get_viewport().set_input_as_handled()
				_select_room(1)
		RunState.CLEARED:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_enter_choice()
		RunState.ROOM:
			_handle_room_input(event)
		RunState.VICTORY:
			pass

func _handle_room_input(event: InputEvent) -> void:
	match _selected_room.get("type", ""):
		"rest":
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_do_rest()
		"shop":
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_room_cleared()
			elif _key(event, KEY_1):
				get_viewport().set_input_as_handled()
				_buy_item(0)
			elif _key(event, KEY_2):
				get_viewport().set_input_as_handled()
				_buy_item(1)
			elif _key(event, KEY_3):
				get_viewport().set_input_as_handled()
				_buy_item(2)
			elif _key(event, KEY_4):
				get_viewport().set_input_as_handled()
				_buy_item(3)
		"event":
			if _key(event, KEY_1):
				get_viewport().set_input_as_handled()
				_choose_event(0)
			elif _key(event, KEY_2):
				get_viewport().set_input_as_handled()
				_choose_event(1)

## ---- 工具 ----
func _key(event: InputEvent, key: Key) -> bool:
	if event is InputEventKey:
		var ke := event as InputEventKey
		return ke.pressed and not ke.echo and ke.keycode == key
	return false

func _set_player_active(active: bool) -> void:
	if is_instance_valid(player):
		player.set_physics_process(active)
		player.velocity = Vector2.ZERO

func _room_label(room: Dictionary) -> String:
	match room.get("type", ""):
		"combat":
			return "战斗房"
		"rest":
			return "休息房"
		"shop":
			return "商店"
		"event":
			return "事件房"
		"boss":
			return "Boss 房"
	return "未知"

func _show_overlay(title: String, body: String) -> void:
	overlay_title.text = title
	overlay_title.visible = title != ""
	overlay_body.text = body
	overlay_panel.visible = true
