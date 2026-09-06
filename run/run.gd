extends Node2D
## Run —— 单局场景：持久持有玩家与 HUD，按房间切换 RoomContainer 内容。
## 房间类型：combat / rest / shop / event / boss；节点图二选一 + 章节首尾剧情。

enum RunState { TITLE, STORY_OPEN, CHOICE, ROOM, EVENT_RESULT, SHOP_RESULT, CLEARED, STORY_CLOSE, VICTORY }

const BASIC_ENEMY_SCENE := preload("res://enemies/basic_enemy.tscn")
const BOSS_ENEMY_SCENE := preload("res://enemies/boss_enemy.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://combat/damage_number.tscn")
const PICKUP_SCENE := preload("res://combat/pickup.tscn")
const FLOAT_TEXT_SCENE := preload("res://combat/float_text.tscn")
const BURST_SCENE := preload("res://combat/burst.tscn")

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
	{
		"title": "废弃的修复舱",
		"text": "一具还能亮灯的修复舱，\n舱内残留着半透明的营养液。",
		"options": [
			{"text": "进入修复", "effect": "heal_full"},
			{"text": "超载激活", "effect": "max_hp_up"},
		],
	},
	{
		"title": "恐惧标本室",
		"text": "一排浸泡着『恐惧因子』的标本罐，\n液面下仿佛有什么在缓缓游动。",
		"options": [
			{"text": "采集惧因子", "effect": "essence_fear2"},
			{"text": "吸收残存能量", "effect": "speed_up"},
		],
	},
	{
		"title": "暴怒注射器阵列",
		"text": "整面墙的自动注射臂仍在滴落『怒因子』，\n针尖寒光毕露。",
		"options": [
			{"text": "全部注入", "effect": "essence_rage2"},
			{"text": "吸收残留怒意", "effect": "attack_up"},
		],
	},
	{
		"title": "混沌培养皿",
		"text": "一尊密封的混沌培养皿，\n内部翻涌着无法辨认的色彩。",
		"options": [
			{"text": "注入混沌", "effect": "chaos_gamble"},
			{"text": "谨慎观察", "effect": "shutdown_minor"},
		],
	},
	{
		"title": "濒死的受试者",
		"text": "一名奄奄一息的受试者靠在墙角，\n身上的注射端口还连着精华袋。",
		"options": [
			{"text": "救助他", "effect": "rescue"},
			{"text": "掠夺他的物资", "effect": "loot"},
		],
	},
]

const STORY_OPENING := "第 1 章 · 暴怒\n\n这片区域的生物被过量注射了『暴怒因子』，\n变得狂暴嗜血、无差别攻击一切。\n\n作为零号受试者，清理失控体、回收因子精华，\n查明失控实验背后的真相。"
const STORY_CLOSING := "你击败了狂暴巨人，暴怒因子的源头暂时平息。\n\n但实验室的更深处，还有更多情绪在失控……"

@onready var room_container: Node2D = $RoomContainer
@onready var fx_layer: Node2D = $FxLayer
@onready var player: Player = $Player
@onready var console_hp_fill: ColorRect = $UILayer/HUD/Console/HPBar/Fill
@onready var console_hp_text: Label = $UILayer/HUD/Console/HPBar/Text
@onready var console_inst_fill: ColorRect = $UILayer/HUD/Console/InstBar/Fill
@onready var console_inst_text: Label = $UILayer/HUD/Console/InstBar/Text
@onready var console_info: Label = $UILayer/HUD/Console/Info
@onready var console_status: Label = $UILayer/HUD/Console/Status
@onready var room_progress_label: Label = $UILayer/HUD/RoomProgress
@onready var interact_prompt: Label = $UILayer/HUD/InteractPrompt
@onready var chapter_title: Label = $UILayer/HUD/ChapterTitle
@onready var victory_panel: ColorRect = $UILayer/HUD/VictoryPanel
@onready var victory_label: Label = $UILayer/HUD/VictoryPanel/VictoryLabel
@onready var overlay_panel: ColorRect = $UILayer/HUD/OverlayPanel
@onready var overlay_title: Label = $UILayer/HUD/OverlayPanel/OverlayTitle
@onready var overlay_body: Label = $UILayer/HUD/OverlayPanel/OverlayBody
@onready var console: Panel = $UILayer/HUD/Console
@onready var hp_bar_bg: Panel = $UILayer/HUD/Console/HPBar
@onready var inst_bar_bg: Panel = $UILayer/HUD/Console/InstBar
@onready var room_pill: Panel = $UILayer/HUD/RoomPill
@onready var overlay_card: Panel = $UILayer/HUD/OverlayPanel/OverlayCard
@onready var victory_sub: Label = $UILayer/HUD/VictoryPanel/VictorySub

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
	EventBus.on("run.currency_changed", _on_currency_changed)
	EventBus.on("fx.float_text", _on_float_text)
	_on_instability_changed(RunManager.instability)
	_on_essence_changed(RunManager.essence)
	_on_currency_changed(RunManager.currency)
	_apply_meta()
	_on_player_hp_changed(player.health.hp)
	_setup_visuals()
	_show_chapter_title()

func _process(_delta: float) -> void:
	_update_status()

## 应用局外 meta 强化（最大生命 / 起始结晶 / 起始精华）。
func _apply_meta() -> void:
	var hp_bonus := MetaManager.get_level("max_hp") * 25
	if hp_bonus > 0:
		player.health.max_hp += hp_bonus
		player.health.hp = player.health.max_hp
		_on_player_hp_changed(player.health.hp)
	player.projectile_damage += MetaManager.get_level("attack") * 3
	player.move_speed *= 1.0 + 0.06 * MetaManager.get_level("move_speed")
	var currency_bonus := MetaManager.get_level("start_currency") * 30
	if currency_bonus > 0:
		RunManager.gain_currency(currency_bonus)
	for i in MetaManager.get_level("start_rage"):
		RunManager.gain_essence("factor_rage")
	for i in MetaManager.get_level("start_fear"):
		RunManager.gain_essence("factor_fear")

## ---- 视觉主题 / 背景 ----
func _setup_visuals() -> void:
	$UILayer/HUD.theme = UITheme.build_theme()
	console.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.05, 0.06, 0.10, 0.86), UITheme.CYAN, 14, 1, 16))
	hp_bar_bg.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.10, 0.10, 0.15, 0.9), Color(0, 0, 0, 0), 5, 0, 0))
	inst_bar_bg.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.10, 0.10, 0.15, 0.9), Color(0, 0, 0, 0), 5, 0, 0))
	room_pill.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.05, 0.06, 0.10, 0.8), UITheme.PANEL_BORDER, 20, 1, 14))
	overlay_card.add_theme_stylebox_override("panel", UITheme.stylebox(UITheme.PANEL, UITheme.CYAN, 16, 1, 30))
	UITheme.label(chapter_title, 56, UITheme.CYAN, 10, 5)
	UITheme.label(interact_prompt, 24, UITheme.GOLD, 6, 3)
	UITheme.label(room_progress_label, 18, UITheme.TEXT, 5, 2)
	UITheme.label(console_hp_text, 14, Color.WHITE, 4, 2)
	UITheme.label(console_inst_text, 12, Color.WHITE, 4, 2)
	UITheme.label(console_info, 15, UITheme.TEXT, 4, 2)
	UITheme.label(console_status, 14, UITheme.TEXT_DIM, 4, 2)
	UITheme.label(victory_label, 56, UITheme.GOLD, 10, 5)
	UITheme.label(victory_sub, 22, UITheme.TEXT, 5, 2)
	UITheme.label(overlay_title, 32, UITheme.CYAN, 7, 3)
	UITheme.label(overlay_body, 21, UITheme.TEXT, 5, 2)
	_setup_run_background()

func _setup_run_background() -> void:
	var bl := CanvasLayer.new()
	bl.layer = -1
	add_child(bl)
	# 地图地板（平铺 + 暗化）
	var floor := TextureRect.new()
	floor.texture = Art.map_texture("factor_rage")
	if floor.texture != null:
		floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor.stretch_mode = TextureRect.STRETCH_TILE
		floor.modulate = Color(0.5, 0.5, 0.58, 1.0)
	else:
		# 回退：网格
		floor.texture = Placeholder.grid_cell(56, Color(0.2, 0.28, 0.36, 0.16))
		floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor.stretch_mode = TextureRect.STRETCH_TILE
	floor.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(floor)
	# 暗角
	var vig := TextureRect.new()
	vig.texture = Placeholder.vignette(256, 0.5, 0.85)
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(vig)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return UITheme.HP
	if ratio > 0.25:
		return UITheme.GOLD
	return UITheme.RAGE

func _inst_color(ratio: float) -> Color:
	return UITheme.PURPLE.lerp(UITheme.RAGE, clampf(ratio, 0.0, 1.0))

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
	room_progress_label.text = "阶段 %s · 种子 %d · %s" % [RunManager.get_stage_progress(), RunManager.seed, RunManager.get_difficulty_name()]

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
	MetaManager.add_cores(10)
	overlay_panel.visible = false
	victory_label.text = "第 %d 章通关！ +10 核心" % RunManager.current_chapter
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
	e.health.max_hp *= RunManager.get_difficulty_mult("hp")
	e.health.hp = e.health.max_hp
	e.attack_damage *= RunManager.get_difficulty_mult("damage")
	var angle := RunManager.rng_randf() * TAU
	var dist := RunManager.rng_randf_range(160.0, 260.0)
	e.global_position = player.global_position + Vector2.from_angle(angle) * dist
	_enemies_alive += 1

func _spawn_boss() -> void:
	var b: BossEnemy = BOSS_ENEMY_SCENE.instantiate()
	room_container.add_child(b)
	b.health.max_hp *= RunManager.get_difficulty_mult("hp")
	b.health.hp = b.health.max_hp
	b.charge_damage *= RunManager.get_difficulty_mult("damage")
	b.global_position = player.global_position + Vector2(0, 200)

func _enter_rest() -> void:
	interact_prompt.text = "休息房 · 按 E 恢复生命并降低失控值"
	interact_prompt.visible = true

func _enter_shop() -> void:
	_show_shop()

func _enter_event() -> void:
	_current_event = EVENTS[RunManager.rng_randi_range(0, EVENTS.size() - 1)]
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
		var result: Dictionary = _apply_effect(str(item["effect"]))
		run_state = RunState.SHOP_RESULT
		_show_overlay("购买成功", str(result.get("text", "")) + "\n\n按 E 返回商店", result.get("color", Color.WHITE))
	else:
		run_state = RunState.SHOP_RESULT
		_show_overlay("购买失败", "结晶不足\n\n按 E 返回商店", Color(1.0, 0.45, 0.45))

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
	var result: Dictionary = _apply_effect(str(options[option_index]["effect"]))
	run_state = RunState.EVENT_RESULT
	_show_overlay("结果", str(result.get("text", "")) + "\n\n按 E 继续", result.get("color", Color.WHITE))

## ---- 效果 ----
## 执行效果并返回结果文本（用于结果页反馈）。
func _apply_effect(effect: String) -> Dictionary:
	var green := Color(0.5, 0.9, 0.5)
	var red := Color(1.0, 0.45, 0.45)
	var cyan := Color(0.6, 0.9, 1.0)
	match effect:
		"heal30":
			player.heal(30.0)
			return {"text": "恢复 30 生命", "color": green}
		"heal_full":
			player.heal(9999.0)
			return {"text": "生命完全恢复", "color": green}
		"max_hp_up":
			player.health.max_hp += 20.0
			player.heal(20.0)
			RunManager.add_instability(20.0)
			return {"text": "最大生命 +20，失控 +20", "color": green}
		"stabilizer":
			RunManager.use_stabilizer()
			return {"text": "失控 -20", "color": green}
		"essence_rage":
			RunManager.gain_essence("factor_rage")
			return {"text": "获得怒精华 ×1", "color": cyan}
		"essence_fear":
			RunManager.gain_essence("factor_fear")
			return {"text": "获得惧精华 ×1", "color": cyan}
		"essence_rage2":
			RunManager.gain_essence("factor_rage")
			RunManager.gain_essence("factor_rage")
			RunManager.add_instability(15.0)
			return {"text": "获得怒精华 ×2，失控 +15", "color": cyan}
		"essence_fear2":
			RunManager.gain_essence("factor_fear")
			RunManager.gain_essence("factor_fear")
			RunManager.add_instability(12.0)
			return {"text": "获得惧精华 ×2，失控 +12", "color": cyan}
		"speed_up":
			player.mods.apply("mod_fear_speed")
			RunManager.add_instability(8.0)
			return {"text": "移速提升（惧疾走），失控 +8", "color": cyan}
		"attack_up":
			player.mods.apply("mod_rage_stack")
			RunManager.add_instability(8.0)
			return {"text": "攻击提升（怒叠层 +3），失控 +8", "color": cyan}
		"drink":
			player.heal(30.0)
			RunManager.add_instability(10.0)
			return {"text": "恢复 30 生命，失控 +10", "color": red}
		"discard":
			RunManager.gain_currency(15)
			return {"text": "获得 15 结晶", "color": cyan}
		"extract":
			RunManager.gain_essence("factor_rage")
			RunManager.add_instability(15.0)
			return {"text": "获得怒精华 ×1，失控 +15", "color": cyan}
		"shutdown":
			RunManager.reduce_instability(10.0)
			return {"text": "失控 -10", "color": green}
		"shutdown_minor":
			RunManager.reduce_instability(5.0)
			return {"text": "失控 -5", "color": green}
		"rescue":
			player.heal(20.0)
			if RunManager.rng_randf() < 0.5:
				RunManager.gain_essence("factor_rage")
				return {"text": "恢复 20 生命，获得怒精华 ×1", "color": green}
			RunManager.gain_essence("factor_fear")
			return {"text": "恢复 20 生命，获得惧精华 ×1", "color": green}
		"loot":
			RunManager.gain_currency(25)
			RunManager.add_instability(10.0)
			return {"text": "获得 25 结晶，失控 +10", "color": red}
		"chaos_gamble":
			return _chaos_gamble()
	return {"text": "", "color": Color.WHITE}

## 混沌注入：高风险高回报的随机结果（受种子控制，可复现）。
func _chaos_gamble() -> Dictionary:
	var cyan := Color(0.6, 0.9, 1.0)
	var red := Color(1.0, 0.45, 0.45)
	var roll := RunManager.rng_randf()
	if roll < 0.4:
		RunManager.gain_essence("factor_rage")
		RunManager.gain_essence("factor_rage")
		RunManager.gain_essence("factor_fear")
		RunManager.gain_essence("factor_fear")
		player.heal(20.0)
		return {"text": "混沌涌动：怒/惧精华各 +2，恢复 20 生命", "color": cyan}
	elif roll < 0.7:
		RunManager.gain_currency(40)
		return {"text": "混沌涌动：获得 40 结晶", "color": cyan}
	player.take_raw_damage(20.0)
	RunManager.add_instability(20.0)
	return {"text": "混沌反噬：受到 20 伤害，失控 +20", "color": red}

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
	RunManager.gain_currency(RunManager.rng_randi_range(3, 6))
	var pos: Vector2 = enemy.global_position
	_spawn_drop.call_deferred(pos)
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_room_cleared()

func _spawn_drop(pos: Vector2) -> void:
	var roll := RunManager.rng_randf()
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
	var max_hp := player.health.max_hp
	var ratio := hp / max_hp if max_hp > 0.0 else 0.0
	_set_bar(console_hp_fill, ratio, _hp_color(ratio))
	console_hp_text.text = "HP %d/%d" % [int(hp), int(max_hp)]

func _on_instability_changed(value: float) -> void:
	var ratio := value / RunManager.INSTABILITY_MAX
	_set_bar(console_inst_fill, ratio, _inst_color(ratio))
	console_inst_text.text = "失控 %d/%d" % [int(value), int(RunManager.INSTABILITY_MAX)]

func _on_essence_changed(_ess: Dictionary) -> void:
	_update_info()

func _on_currency_changed(_value: int) -> void:
	_update_info()

func _update_info() -> void:
	console_info.text = "结晶 ×%d\n怒精华 ×%d · 惧精华 ×%d" % [
		RunManager.currency,
		RunManager.get_essence("factor_rage"),
		RunManager.get_essence("factor_fear"),
	]

func _on_float_text(payload: Dictionary) -> void:
	var text: String = payload.get("text", "")
	var pos: Vector2 = payload.get("pos", Vector2.ZERO)
	var color: Color = payload.get("color", Color.WHITE)
	var ft: Label = FLOAT_TEXT_SCENE.instantiate()
	fx_layer.add_child(ft)
	ft.setup(text, pos, color)
	var burst: Sprite2D = BURST_SCENE.instantiate()
	fx_layer.add_child(burst)
	burst.setup(pos, color)

func _set_bar(fill: ColorRect, ratio: float, color: Color) -> void:
	var bg: Control = fill.get_parent() as Control
	fill.size = Vector2(bg.size.x * clampf(ratio, 0.0, 1.0), bg.size.y)
	fill.position = Vector2.ZERO
	fill.color = color

func _update_status() -> void:
	if not is_instance_valid(player):
		return
	var rage := player.mods.get_stacks("mod_rage_stack")
	var fear := player.mods.get_stacks("mod_fear_speed")
	var state_text := "失控" if RunManager.is_unstable else "稳定"
	console_status.text = "攻击 %d · 移速 %d\n怒叠层 %d · 惧叠层 %d\n状态：%s" % [
		int(player.get_effective_attack()), int(player.get_effective_move_speed()),
		rage, fear, state_text,
	]
	console_status.modulate = Color(1.0, 0.5, 0.5) if RunManager.is_unstable else Color.WHITE

## ---- 输入 ----
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameManager.back_to_lobby()
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
		RunState.EVENT_RESULT:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_room_cleared()
		RunState.SHOP_RESULT:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				run_state = RunState.ROOM
				_show_shop()
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

func _show_overlay(title: String, body: String, color: Color = Color.WHITE) -> void:
	overlay_title.text = title
	overlay_title.visible = title != ""
	overlay_body.text = body
	overlay_body.add_theme_color_override("font_color", color)
	overlay_panel.visible = true
