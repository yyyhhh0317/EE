extends Node2D
## Run —— 单局场景（v0.2 重构）：持久持有玩家与 HUD，按房间切换内容。
## 新增玩法：双轨资源 HUD + 六边形构筑面板 + 慢动作选槽注射（仪式感）+
## 临界红晕/暴走脉冲 + 情绪污染 + 情绪过载 + 情绪风暴大招 + 记忆碎片结算。

enum RunState { TITLE, STORY_OPEN, CHOICE, ROOM, EVENT_RESULT, SHOP_RESULT, INJECT_PICK, CLEARED, STORY_CLOSE, VICTORY, GAME_OVER }

const BASIC_ENEMY_SCENE := preload("res://enemies/basic_enemy.tscn")
const BOSS_ENEMY_SCENE := preload("res://enemies/boss_enemy.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://combat/damage_number.tscn")
const PICKUP_SCENE := preload("res://combat/pickup.tscn")
const FLOAT_TEXT_SCENE := preload("res://combat/float_text.tscn")
const BURST_SCENE := preload("res://combat/burst.tscn")

const INJECT_FACTORS := ["factor_rage", "factor_fear", "factor_joy", "factor_sorrow"]
const INJECT_SLOWMO := 0.2

const SHOP_ITEMS := [
	{"name": "恢复 30 HP", "price": 15, "effect": "heal30"},
	{"name": "稳定剂（-20 失控）", "price": 20, "effect": "stabilizer"},
	{"name": "怒精华 ×1", "price": 25, "effect": "essence_rage"},
	{"name": "惧精华 ×1", "price": 25, "effect": "essence_fear"},
	{"name": "喜精华 ×1", "price": 25, "effect": "essence_joy"},
	{"name": "哀精华 ×1", "price": 25, "effect": "essence_sorrow"},
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
		"title": "欢愉剧场",
		"text": "废弃的剧场里，聚光灯竟在无人时亮起，\n空气中残留着致幻的欢愉因子。",
		"options": [
			{"text": "采集喜因子", "effect": "essence_joy2"},
			{"text": "加入狂欢", "effect": "crit_up"},
		],
	},
	{
		"title": "哀悼长廊",
		"text": "长廊两侧摆满无名墓碑，\n哀恸因子像细雨一样飘落。",
		"options": [
			{"text": "采集哀因子", "effect": "essence_sorrow2"},
			{"text": "静默疗愈", "effect": "sanity_restore"},
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

const STORY_OPENING := "第 1 章 · 暴怒\n\n这片区域的生物被过量注射了『暴怒因子』，\n变得狂暴嗜血、无差别攻击一切。\n\n你是零号受试者：\n· 注射情绪因子构筑共鸣，把失控压在 70% 临界区白嫖增益\n· 失控 100% 触发暴走：伤害暴涨，但理智被吞噬\n· 理智归零 = 失控自毁\n\n清理失控体，查明失控实验背后的真相。"
const STORY_CLOSING := "你击败了狂暴巨人，暴怒因子的源头暂时平息。\n\n但实验室的更深处，还有更多情绪在失控……"

@onready var room_container: Node2D = $RoomContainer
@onready var fx_layer: Node2D = $FxLayer
@onready var player: Player = $Player
@onready var console: Panel = $UILayer/HUD/Console
@onready var console_hp_fill: ColorRect = $UILayer/HUD/Console/HPBar/Fill
@onready var console_hp_text: Label = $UILayer/HUD/Console/HPBar/Text
@onready var console_san_fill: ColorRect = $UILayer/HUD/Console/SanityBar/Fill
@onready var console_san_text: Label = $UILayer/HUD/Console/SanityBar/Text
@onready var console_over_fill: ColorRect = $UILayer/HUD/Console/OverheatBar/Fill
@onready var console_over_tick: ColorRect = $UILayer/HUD/Console/OverheatBar/Tick
@onready var console_over_text: Label = $UILayer/HUD/Console/OverheatBar/Text
@onready var console_info: Label = $UILayer/HUD/Console/Info
@onready var console_status: Label = $UILayer/HUD/Console/Status
@onready var room_progress_label: Label = $UILayer/HUD/RoomProgress
@onready var interact_prompt: Label = $UILayer/HUD/InteractPrompt
@onready var chapter_title: Label = $UILayer/HUD/ChapterTitle
@onready var announce_label: Label = $UILayer/HUD/Announce
@onready var danger_vignette: TextureRect = $UILayer/HUD/DangerVignette
@onready var fog_rect: ColorRect = $UILayer/HUD/FogRect
@onready var berserk_tint: ColorRect = $UILayer/HUD/BerserkTint
@onready var flash_rect: ColorRect = $UILayer/HUD/FlashRect
@onready var victory_panel: ColorRect = $UILayer/HUD/VictoryPanel
@onready var victory_label: Label = $UILayer/HUD/VictoryPanel/VictoryLabel
@onready var victory_sub: Label = $UILayer/HUD/VictoryPanel/VictorySub
@onready var game_over_panel: ColorRect = $UILayer/HUD/GameOverPanel
@onready var game_over_label: Label = $UILayer/HUD/GameOverPanel/GameOverLabel
@onready var game_over_sub: Label = $UILayer/HUD/GameOverPanel/GameOverSub
@onready var overlay_panel: ColorRect = $UILayer/HUD/OverlayPanel
@onready var overlay_title: Label = $UILayer/HUD/OverlayPanel/OverlayTitle
@onready var overlay_body: Label = $UILayer/HUD/OverlayPanel/OverlayBody
@onready var hp_bar_bg: Panel = $UILayer/HUD/Console/HPBar
@onready var san_bar_bg: Panel = $UILayer/HUD/Console/SanityBar
@onready var over_bar_bg: Panel = $UILayer/HUD/Console/OverheatBar
@onready var room_pill: Panel = $UILayer/HUD/RoomPill
@onready var overlay_card: Panel = $UILayer/HUD/OverlayPanel/OverlayCard

var run_state: RunState = RunState.TITLE
var _enemies_alive: int = 0
var _selected_room: Dictionary = {}
var _current_event: Dictionary = {}
var _pick_factor: String = ""
var _before_resonances: Dictionary = {}
var _before_opposites: Array = []
var _scorch_timer: float = 0.0
var _whisper_timer: float = 0.0
var _floor_rect: TextureRect = null
var _floor_map_id: String = ""

func _ready() -> void:
	print("[Run] 单局开始（v0.2 玩法重构）。")
	EventBus.on("combat.damage_dealt", _on_damage_dealt)
	EventBus.on("combat.entity_died", _on_entity_died)
	EventBus.on("player.hp_changed", _on_player_hp_changed)
	EventBus.on("player.died", _on_player_died)
	EventBus.on("run.essence_changed", _on_essence_changed)
	EventBus.on("run.currency_changed", _on_currency_changed)
	EventBus.on("run.state_changed", _on_run_state_changed)
	EventBus.on("run.ended", _on_run_ended)
	EventBus.on("build.overload", _on_overload)
	EventBus.on("fx.float_text", _on_float_text)
	RunManager.set_player_ref(player)
	_on_essence_changed(RunManager.essence)
	_on_currency_changed(RunManager.currency)
	_apply_meta()
	_on_player_hp_changed(player.health.hp)
	_setup_visuals()
	_show_chapter_title()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	_update_status()
	_update_resource_bars()
	_update_danger_fx(delta)
	_update_pollution_fx(delta)

## 应用局外 meta 强化（最大生命 / 起始结晶 / 起始精华）。
func _apply_meta() -> void:
	var hp_bonus := MetaManager.get_level("max_hp") * 25
	if hp_bonus > 0:
		player.health.max_hp += hp_bonus
		player.health.hp = player.health.max_hp
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
	san_bar_bg.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.10, 0.10, 0.15, 0.9), Color(0, 0, 0, 0), 5, 0, 0))
	over_bar_bg.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.10, 0.10, 0.15, 0.9), Color(0, 0, 0, 0), 5, 0, 0))
	room_pill.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.05, 0.06, 0.10, 0.8), UITheme.PANEL_BORDER, 20, 1, 14))
	overlay_card.add_theme_stylebox_override("panel", UITheme.card_stylebox(UITheme.CYAN))
	UITheme.label(chapter_title, 56, UITheme.CYAN, 10, 5)
	UITheme.label(interact_prompt, 24, UITheme.GOLD, 6, 3)
	UITheme.label(room_progress_label, 18, UITheme.TEXT, 5, 2)
	UITheme.label(console_hp_text, 14, Color.WHITE, 4, 2)
	UITheme.label(console_san_text, 12, Color.WHITE, 4, 2)
	UITheme.label(console_over_text, 12, Color.WHITE, 4, 2)
	UITheme.label(console_info, 15, UITheme.TEXT, 4, 2)
	UITheme.label(console_status, 14, UITheme.TEXT_DIM, 4, 2)
	UITheme.label(victory_label, 56, UITheme.GOLD, 10, 5)
	UITheme.label(victory_sub, 22, UITheme.TEXT, 5, 2)
	UITheme.label(game_over_label, 56, UITheme.RAGE, 10, 5)
	UITheme.label(game_over_sub, 22, UITheme.TEXT, 5, 2)
	UITheme.label(overlay_title, 32, UITheme.CYAN, 7, 3)
	UITheme.label(overlay_body, 21, UITheme.TEXT, 5, 2)
	UITheme.label(announce_label, 34, UITheme.CYAN, 8, 4)
	# HUD 图标：生命 / 理智 / 失控（素材缺失自动跳过）
	_add_bar_icon(hp_bar_bg, Art.item_icon("hp"))
	_add_bar_icon(san_bar_bg, Art.item_icon("san"))
	_add_bar_icon(over_bar_bg, Art.item_icon("unstable"))
	danger_vignette.texture = Placeholder.vignette(256, 0.55, 0.8)
	danger_vignette.modulate = Color(1.0, 0.15, 0.15, 0.0)
	_setup_run_background()

## 在状态条左端放置一枚 HUD 图标。
func _add_bar_icon(bar: Panel, tex: Texture2D) -> void:
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(16, 16)
	icon.position = Vector2(5, (bar.size.y - 16.0) * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(icon)

func _setup_run_background() -> void:
	var bl := CanvasLayer.new()
	bl.layer = -1
	add_child(bl)
	# 地图地板（平铺 + 暗化）；情绪污染时会换到对应情绪地图
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
	_floor_rect = floor
	_floor_map_id = "factor_rage"
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

func _over_color(ratio: float) -> Color:
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
	RunManager.end_run(true)

## ---- 房间内容 ----
func _clear_room() -> void:
	for c in room_container.get_children():
		c.queue_free()
	for c in fx_layer.get_children():
		c.queue_free()
	_enemies_alive = 0
	_scorch_timer = 0.0

func _spawn_combat(count: int) -> void:
	for i in count:
		_spawn_enemy()

func _spawn_enemy() -> void:
	var e: BasicEnemy = BASIC_ENEMY_SCENE.instantiate()
	room_container.add_child(e)
	e.health.max_hp *= RunManager.get_difficulty_mult("hp")
	e.health.hp = e.health.max_hp
	# 动态难度取代固定伤害倍率（见 CombatResolver）；光污染加速敌人
	if BuildManager.dominant_pollution() == "joy":
		e.move_speed *= 1.1
	var angle := RunManager.rng_randf() * TAU
	var dist := RunManager.rng_randf_range(160.0, 260.0)
	e.global_position = player.global_position + Vector2.from_angle(angle) * dist
	_enemies_alive += 1

func _spawn_boss() -> void:
	var b: BossEnemy = BOSS_ENEMY_SCENE.instantiate()
	room_container.add_child(b)
	b.health.max_hp *= RunManager.get_difficulty_mult("hp")
	b.health.hp = b.health.max_hp
	b.global_position = player.global_position + Vector2(0, 200)

func _enter_rest() -> void:
	interact_prompt.text = "休息房 · 按 E 恢复生命、理智并降低失控值"
	interact_prompt.visible = true

func _enter_shop() -> void:
	_show_shop()

func _enter_event() -> void:
	_current_event = EVENTS[RunManager.rng_randi_range(0, EVENTS.size() - 1)]
	_show_event(_current_event)

## ---- 商店 / 事件 ----
func _shop_items() -> Array:
	var items: Array = []
	for it in SHOP_ITEMS:
		var eff := str(it["effect"])
		if eff.begins_with("essence_") and MetaManager.is_banned(eff.replace("essence_", "factor_")):
			continue
		items.append(it)
	return items

func _show_shop() -> void:
	var items := _shop_items()
	var lines: Array = []
	for i in items.size():
		lines.append("%d. %s — %d 结晶" % [i + 1, items[i]["name"], items[i]["price"]])
	var body := "\n".join(lines) + "\n\n按 1-%d 购买 · E 离开" % items.size()
	_show_overlay("商店（结晶 ×%d）" % RunManager.currency, body)

func _buy_item(index: int) -> void:
	var items := _shop_items()
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
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
			RunManager.add_overheat(20.0)
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
		"essence_joy":
			RunManager.gain_essence("factor_joy")
			return {"text": "获得喜精华 ×1", "color": cyan}
		"essence_sorrow":
			RunManager.gain_essence("factor_sorrow")
			return {"text": "获得哀精华 ×1", "color": cyan}
		"essence_rage2":
			RunManager.gain_essence("factor_rage")
			RunManager.gain_essence("factor_rage")
			RunManager.add_overheat(15.0)
			return {"text": "获得怒精华 ×2，失控 +15", "color": cyan}
		"essence_fear2":
			RunManager.gain_essence("factor_fear")
			RunManager.gain_essence("factor_fear")
			RunManager.add_overheat(12.0)
			return {"text": "获得惧精华 ×2，失控 +12", "color": cyan}
		"essence_joy2":
			RunManager.gain_essence("factor_joy")
			RunManager.gain_essence("factor_joy")
			RunManager.add_overheat(12.0)
			return {"text": "获得喜精华 ×2，失控 +12", "color": cyan}
		"essence_sorrow2":
			RunManager.gain_essence("factor_sorrow")
			RunManager.gain_essence("factor_sorrow")
			RunManager.add_overheat(12.0)
			return {"text": "获得哀精华 ×2，失控 +12", "color": cyan}
		"speed_up":
			player.mods.apply("mod_fear_speed")
			RunManager.add_overheat(8.0)
			return {"text": "移速提升（惧疾走），失控 +8", "color": cyan}
		"attack_up":
			player.mods.apply("mod_rage_stack")
			RunManager.add_overheat(8.0)
			return {"text": "攻击提升（怒叠层 +3），失控 +8", "color": cyan}
		"crit_up":
			player.mods.apply("mod_joy_crit")
			RunManager.add_overheat(8.0)
			return {"text": "暴击率提升（欢愉暴击），失控 +8", "color": cyan}
		"sanity_restore":
			RunManager.add_sanity(30.0)
			RunManager.reduce_overheat(5.0)
			return {"text": "理智 +30，失控 -5", "color": green}
		"drink":
			player.heal(30.0)
			RunManager.add_overheat(10.0)
			return {"text": "恢复 30 生命，失控 +10", "color": red}
		"discard":
			RunManager.gain_currency(15)
			return {"text": "获得 15 结晶", "color": cyan}
		"extract":
			RunManager.gain_essence("factor_rage")
			RunManager.add_overheat(15.0)
			return {"text": "获得怒精华 ×1，失控 +15", "color": cyan}
		"shutdown":
			RunManager.reduce_overheat(10.0)
			return {"text": "失控 -10", "color": green}
		"shutdown_minor":
			RunManager.reduce_overheat(5.0)
			return {"text": "失控 -5", "color": green}
		"rescue":
			player.heal(20.0)
			var pool: Array = ["factor_rage", "factor_fear", "factor_joy", "factor_sorrow"]
			pool = pool.filter(func(f): return not MetaManager.is_banned(str(f)))
			if not pool.is_empty():
				var fid: String = pool[RunManager.rng_randi_range(0, pool.size() - 1)]
				RunManager.gain_essence(fid)
				return {"text": "恢复 20 生命，获得精华 ×1", "color": green}
			return {"text": "恢复 20 生命", "color": green}
		"loot":
			RunManager.gain_currency(25)
			RunManager.add_overheat(10.0)
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
	RunManager.add_overheat(20.0)
	return {"text": "混沌反噬：受到 20 伤害，失控 +20", "color": red}

## ---- 注射（慢动作选槽 · 仪式感） ----
func _open_inject_picker(factor_index: int) -> void:
	if factor_index < 0 or factor_index >= INJECT_FACTORS.size():
		return
	var factor_id: String = INJECT_FACTORS[factor_index]
	if RunManager.get_essence(factor_id) <= 0:
		_toast("精华不足")
		return
	_pick_factor = factor_id
	_before_resonances = BuildManager.get_adjacent_resonance_stacks()
	_before_opposites = BuildManager.get_active_opposites()
	run_state = RunState.INJECT_PICK
	_set_player_active(false)
	Engine.time_scale = INJECT_SLOWMO
	var f := DataManager.get_factor(factor_id)
	var body := "剩余精华 ×%d\n\n%s\n\n%s\n\n按 1-6 选槽 · Esc 取消" % [
		RunManager.get_essence(factor_id), _slot_lines(), str(f.get("description", ""))
	]
	_show_overlay("注射 %s（选择槽位）" % str(f.get("name", "因子")), body)

func _slot_lines() -> String:
	var lines: Array = []
	for i in BuildManager.SLOT_COUNT:
		var s := BuildManager.get_slot(i)
		if str(s["factor_id"]) == "":
			lines.append("%d. 槽 %d · 空" % [i + 1, i + 1])
		else:
			lines.append("%d. 槽 %d · %s Lv.%d" % [i + 1, i + 1, _factor_name(str(s["factor_id"])), int(s["level"])])
	return "\n".join(lines)

func _confirm_inject(slot_index: int) -> void:
	Engine.time_scale = 1.0
	var res := RunManager.inject_factor(_pick_factor, slot_index)
	if bool(res.get("ok", false)):
		_injection_ceremony(_pick_factor, slot_index, int(res.get("level", 1)), str(res.get("replaced", "")))
		var kinds := BuildManager.diff_events(_before_resonances, _before_opposites)
		for k in kinds:
			BuildManager.record_event(k)
	overlay_panel.visible = false
	run_state = RunState.ROOM
	_set_player_active(true)

func _cancel_inject() -> void:
	Engine.time_scale = 1.0
	overlay_panel.visible = false
	run_state = RunState.ROOM
	_set_player_active(true)

func _injection_ceremony(factor_id: String, slot: int, level: int, replaced: String) -> void:
	player.injection_fx(factor_id)
	_flash()
	var f := DataManager.get_factor(factor_id)
	var name := str(f.get("name", "因子"))
	var dil := BuildManager.dilution(str(f.get("emotion", "")))
	var txt := "【%s】注入 %d 号槽 Lv.%d" % [name, slot + 1, level]
	if replaced != "":
		txt += "（替换 %s）" % _factor_name(replaced)
	txt += "\n词条生效 · 稀释系数 ×%.2f" % dil
	_announce(txt, Color(str(f.get("color", "#4dd8ff"))))
	var burst: Sprite2D = BURST_SCENE.instantiate()
	fx_layer.add_child(burst)
	burst.setup(player.global_position, Color(str(f.get("color", "#4dd8ff"))))

## ---- 情绪风暴（共振回路大招） ----
func _trigger_ultimate() -> void:
	if not RunManager.can_ultimate():
		_toast("回路未闭合或冷却中")
		return
	if not RunManager.spend_sanity(RunManager.ULTIMATE_SANITY_COST):
		_toast("理智不足")
		return
	RunManager.use_ultimate()
	var dmg := 120.0 + 40.0 * float(BuildManager.get_total_levels())
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e):
			CombatResolver.deal_damage(e, dmg, player)
			var burst: Sprite2D = BURST_SCENE.instantiate()
			fx_layer.add_child(burst)
			burst.setup(e.global_position, UITheme.PURPLE)
	RunManager.add_overheat(RunManager.ULTIMATE_OVERHEAT_GAIN)
	BuildManager.degrade_all()
	BuildManager.record_event("storm")
	_flash()
	_announce("情绪风暴！", UITheme.PURPLE)

## ---- 交互 ----
func _do_rest() -> void:
	player.heal(40.0)
	RunManager.reduce_overheat(RunManager.REST_INSTABILITY_REDUCE)
	RunManager.add_sanity(RunManager.REST_SANITY_HEAL)
	_room_cleared()

## ---- 事件回调 ----
func _on_damage_dealt(payload: Dictionary) -> void:
	var target: Node = payload.get("target")
	var amount: float = payload.get("amount", 0.0)
	if not is_instance_valid(target):
		return
	var meta: Dictionary = payload.get("meta", {})
	var color := Color(1.0, 0.35, 0.35)
	if target.is_in_group("player"):
		color = Color(1.0, 0.35, 0.35)
	elif bool(meta.get("crit", false)):
		color = player._dominant_emotion_color() if is_instance_valid(player) else Color(1.0, 0.95, 0.5)
	else:
		color = Color(1.0, 0.95, 0.5)
	var num: Node2D = DAMAGE_NUMBER_SCENE.instantiate()
	fx_layer.add_child(num)
	num.setup(amount, target.global_position, color, bool(meta.get("crit", false)))
	if bool(meta.get("crit", false)):
		var ft: Label = FLOAT_TEXT_SCENE.instantiate()
		fx_layer.add_child(ft)
		ft.setup("暴击！", target.global_position + Vector2(0, -26), color)

func _on_entity_died(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	RunManager.register_kill()
	if is_instance_valid(player):
		player.on_kill(enemy)
	if enemy.is_in_group("boss"):
		_enter_story_close()
		return
	RunManager.gain_currency(RunManager.rng_randi_range(3, 6))
	var pos: Vector2 = enemy.global_position
	_spawn_drop.call_deferred(pos)
	# 动态难度高时掉落品质提升：概率双倍掉落
	if RunManager.enemy_damage_mult() >= 1.3 and RunManager.rng_randf() < 0.3:
		_spawn_drop.call_deferred(pos + Vector2(24, 0))
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_room_cleared()

func _spawn_drop(pos: Vector2) -> void:
	var pool: Array = [
		["factor_rage", 0.30], ["factor_fear", 0.30],
		["factor_joy", 0.20], ["factor_sorrow", 0.20], ["stabilizer", 0.18],
	]
	var total := 0.0
	for p in pool:
		if MetaManager.is_banned(str(p[0])):
			continue
		total += float(p[1])
	var roll := RunManager.rng_randf() * total
	var acc := 0.0
	for p in pool:
		if MetaManager.is_banned(str(p[0])):
			continue
		acc += float(p[1])
		if roll <= acc:
			var pk: Pickup = PICKUP_SCENE.instantiate()
			fx_layer.add_child(pk)
			pk.setup(str(p[0]), pos)
			return

func _on_player_hp_changed(hp: float) -> void:
	var max_hp := player.health.max_hp
	var ratio := hp / max_hp if max_hp > 0.0 else 0.0
	_set_bar(console_hp_fill, ratio, _hp_color(ratio))
	console_hp_text.text = "HP %d/%d" % [int(hp), int(max_hp)]

func _update_resource_bars() -> void:
	# 理智（白条）
	var san_ratio := RunManager.sanity / RunManager.SANITY_MAX
	_set_bar(console_san_fill, san_ratio, Color(0.85, 0.93, 1.0))
	console_san_text.text = "理智 %d/%d" % [int(RunManager.sanity), int(RunManager.SANITY_MAX)]
	# 失控（红条）+ 临界刻度
	var over_ratio := RunManager.overheat / RunManager.OVERHEAT_MAX
	_set_bar(console_over_fill, over_ratio, _over_color(over_ratio))
	console_over_text.text = "失控 %d/%d" % [int(RunManager.overheat), int(RunManager.OVERHEAT_MAX)]
	var bg: Control = console_over_fill.get_parent() as Control
	console_over_tick.visible = true
	console_over_tick.size = Vector2(2.0, bg.size.y)
	console_over_tick.position = Vector2(bg.size.x * RunManager.excite_threshold(), 0.0)

func _on_essence_changed(_ess: Dictionary) -> void:
	_update_info()

func _on_currency_changed(_value: int) -> void:
	_update_info()

func _update_info() -> void:
	console_info.text = "结晶 ×%d\n怒 ×%d · 惧 ×%d · 喜 ×%d · 哀 ×%d" % [
		RunManager.currency,
		RunManager.get_essence("factor_rage"),
		RunManager.get_essence("factor_fear"),
		RunManager.get_essence("factor_joy"),
		RunManager.get_essence("factor_sorrow"),
	]

func _update_status() -> void:
	if not is_instance_valid(player):
		return
	var atk := player.get_effective_attack()
	var rate := 1.0 / maxf(0.01, player.get_effective_fire_rate())
	var crit := player.get_effective_crit_chance()
	var dps := atk * rate * (1.0 + crit)
	var pollution := BuildManager.dominant_pollution()
	var pollution_name := ""
	if pollution != "":
		pollution_name = str(BuildManager.get_pollution_row(pollution).get("name", pollution))
	var state_color := Color.WHITE
	match RunManager.state:
		RunManager.State.EXCITED:
			state_color = UITheme.GOLD
		RunManager.State.BERSERK:
			state_color = UITheme.RAGE
		RunManager.State.COOLDOWN:
			state_color = UITheme.PURPLE
	console_status.text = "攻击 %d · 攻速 %.1f/s · 暴击 %d%%\nDPS ≈ %d · 状态：%s\n污染：%s" % [
		int(atk), rate, int(crit * 100.0), int(dps),
		RunManager.get_state_name(), pollution_name if pollution_name != "" else "无",
	]
	console_status.modulate = state_color

## ---- 临界/污染反馈 ----
func _update_danger_fx(_delta: float) -> void:
	if not RunManager.is_running:
		return
	var r := RunManager.overheat / RunManager.OVERHEAT_MAX
	var threshold := RunManager.excite_threshold()
	var a := 0.0
	if r >= threshold:
		a = clampf((r - threshold) / (1.0 - threshold), 0.0, 1.0) * 0.85
	danger_vignette.modulate = Color(1.0, 0.15, 0.15, a)
	if RunManager.state == RunManager.State.BERSERK:
		var pulse := 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.02)
		berserk_tint.color = Color(1.0, 0.1, 0.15, pulse)
	else:
		berserk_tint.color = Color(1.0, 0.1, 0.15, 0.0)

func _update_pollution_fx(delta: float) -> void:
	if not RunManager.is_running:
		return
	var pollution := BuildManager.dominant_pollution()
	# 情绪污染 → 地板换色（8 张情绪地图同构异色，无感切换）
	var map_id := "factor_rage"
	if pollution != "" and Art.map_texture("factor_" + pollution) != null:
		map_id = "factor_" + pollution
	if map_id != _floor_map_id and _floor_rect != null:
		_floor_map_id = map_id
		var t := Art.map_texture(map_id)
		if t != null:
			_floor_rect.texture = t
			_floor_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			_floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	# 哀污染：浓雾
	fog_rect.visible = pollution == "sorrow"
	# 惧污染：低语幻影（屏幕抖动）
	_whisper_timer += delta
	if pollution != "fear":
		_whisper_timer = 0.0
		if is_instance_valid(player):
			player.camera.offset = Vector2.ZERO
	elif _whisper_timer >= 0.7:
		_whisper_timer = 0.0
		if is_instance_valid(player):
			player.camera.offset = Vector2(RunManager.rng_randf_range(-4.0, 4.0), RunManager.rng_randf_range(-4.0, 4.0))
	# 怒污染：焦土地狱（仅战斗房）
	if pollution == "rage" and run_state == RunState.ROOM and str(_selected_room.get("type", "")) in ["combat", "boss"]:
		_scorch_timer += delta
		if _scorch_timer >= 1.5:
			_scorch_timer = 0.0
			player.take_raw_damage(2.0)
			EventBus.emit("fx.float_text", {"text": "灼烧 -2", "pos": player.global_position + Vector2(0, -46), "color": UITheme.RAGE})
	else:
		_scorch_timer = 0.0

## ---- 状态横幅 / 情绪过载 ----
func _on_run_state_changed(payload: Dictionary) -> void:
	var to_state: int = int(payload.get("to", 0))
	match to_state:
		RunManager.State.EXCITED:
			_announce("临界亢奋！移速/攻速提升 · 冲刺禁用", UITheme.GOLD)
		RunManager.State.BERSERK:
			_flash()
			_announce("临界突破 · 暴走！伤害 +50% · 理智被吞噬", UITheme.RAGE)
		RunManager.State.COOLDOWN:
			_announce("暴走结束 · 冷却中", UITheme.PURPLE)

func _on_overload(_payload) -> void:
	player.set_invincible(1.5)
	_flash()
	_announce("情绪过载 · 1.5s 无敌", UITheme.GOLD)

## ---- 死亡 / 结算 ----
func _on_player_died(_payload) -> void:
	_run_end_sequence(false)

func _run_end_sequence(victory: bool) -> void:
	_set_player_active(false)
	RunManager.end_run(victory)

func _on_run_ended(payload: Dictionary) -> void:
	var victory := bool(payload.get("victory", false))
	var shards := int(payload.get("shards", 0))
	overlay_panel.visible = false
	if victory:
		victory_label.text = "第 %d 章通关！ +10 核心" % RunManager.current_chapter
		victory_sub.text = "记忆碎片 +%d · 按 Esc 返回大厅" % shards
		victory_panel.visible = true
		run_state = RunState.VICTORY
	else:
		game_over_label.text = "你失控了…"
		game_over_sub.text = "记忆碎片 +%d · 按 Esc 返回大厅" % shards
		game_over_panel.visible = true
		run_state = RunState.GAME_OVER
	_set_player_active(false)

## ---- 反馈工具 ----
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

func _flash() -> void:
	flash_rect.color = Color(1, 1, 1, 0.85)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color", Color(1, 1, 1, 0.0), 0.35)

func _announce(text: String, color: Color) -> void:
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	announce_label.modulate = Color(1, 1, 1, 0)
	announce_label.scale = Vector2(0.85, 0.85)
	announce_label.pivot_offset = announce_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(announce_label, "modulate", Color(1, 1, 1, 1), 0.15)
	tw.parallel().tween_property(announce_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(announce_label, "modulate", Color(1, 1, 1, 0), 0.4)

func _toast(text: String) -> void:
	EventBus.emit("fx.float_text", {"text": text, "pos": player.global_position + Vector2(0, -46), "color": UITheme.TEXT_DIM})

func _set_bar(fill: ColorRect, ratio: float, color: Color) -> void:
	var bg: Control = fill.get_parent() as Control
	fill.size = Vector2(bg.size.x * clampf(ratio, 0.0, 1.0), bg.size.y)
	fill.position = Vector2.ZERO
	fill.color = color

## ---- 输入 ----
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if run_state == RunState.INJECT_PICK:
			# 选槽中 Esc = 取消注射（而非退回大厅）
			_cancel_inject()
			return
		Engine.time_scale = 1.0
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
		RunState.INJECT_PICK:
			if _key(event, KEY_1):
				get_viewport().set_input_as_handled()
				_confirm_inject(0)
			elif _key(event, KEY_2):
				get_viewport().set_input_as_handled()
				_confirm_inject(1)
			elif _key(event, KEY_3):
				get_viewport().set_input_as_handled()
				_confirm_inject(2)
			elif _key(event, KEY_4):
				get_viewport().set_input_as_handled()
				_confirm_inject(3)
			elif _key(event, KEY_5):
				get_viewport().set_input_as_handled()
				_confirm_inject(4)
			elif _key(event, KEY_6):
				get_viewport().set_input_as_handled()
				_confirm_inject(5)
			elif _key(event, KEY_ESCAPE):
				get_viewport().set_input_as_handled()
				_cancel_inject()
		RunState.CLEARED:
			if event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_enter_choice()
		RunState.ROOM:
			_handle_room_input(event)
		RunState.VICTORY, RunState.GAME_OVER:
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
			else:
				for k in range(1, 7):
					if _key(event, int(KEY_1) + (k - 1)):
						get_viewport().set_input_as_handled()
						_buy_item(k - 1)
		"event":
			if _key(event, KEY_1):
				get_viewport().set_input_as_handled()
				_choose_event(0)
			elif _key(event, KEY_2):
				get_viewport().set_input_as_handled()
				_choose_event(1)
		"combat", "boss":
			for k in range(4):
				if _key(event, int(KEY_1) + k):
					get_viewport().set_input_as_handled()
					_open_inject_picker(k)
			if _key(event, KEY_F):
				get_viewport().set_input_as_handled()
				_trigger_ultimate()

## ---- 工具 ----
func _key(event: InputEvent, key: int) -> bool:
	if event is InputEventKey:
		var ke := event as InputEventKey
		return ke.pressed and not ke.echo and int(ke.keycode) == key
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

func _factor_name(factor_id: String) -> String:
	var f := DataManager.get_factor(factor_id)
	if f.is_empty():
		return factor_id
	return str(f.get("name", factor_id))

func _show_overlay(title: String, body: String, color: Color = Color.WHITE) -> void:
	overlay_title.text = title
	overlay_title.visible = title != ""
	overlay_body.text = body
	overlay_body.add_theme_color_override("font_color", color)
	overlay_panel.visible = true
