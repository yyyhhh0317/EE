extends Control
## 大厅（局外 Hub）· v0.2：选章节 + 难度 + 种子 + 商店（核心强化）+ 记忆碎片（禁因子/预设共鸣）。
## 视觉：渐变背景 + 漂浮因子光球 + 圆角卡片。

@onready var title_label: Label = $Title
@onready var cores_label: Label = $CoresLabel
@onready var shards_box: HBoxContainer = $ShardsBox
@onready var shards_label: Label = $ShardsBox/ShardsLabel
@onready var difficulty_button: Button = $BottomButtons/DifficultyButton
@onready var shop_button: Button = $BottomButtons/ShopButton
@onready var frag_shop_button: Button = $BottomButtons/FragShopButton
@onready var back_button: Button = $BottomButtons/BackButton
@onready var seed_label: Label = $SeedBox/SeedLabel
@onready var seed_input: LineEdit = $SeedBox/SeedInput
@onready var shop_panel: Panel = $ShopPanel
@onready var shop_card: Panel = $ShopPanel/ShopCard
@onready var shop_title: Label = $ShopPanel/ShopTitle
@onready var shop_body: Label = $ShopPanel/ShopBody
@onready var fragment_panel: Panel = $FragmentPanel
@onready var fragment_card: Panel = $FragmentPanel/FragmentCard
@onready var fragment_title: Label = $FragmentPanel/FragmentTitle
@onready var fragment_body: Label = $FragmentPanel/FragmentBody

const FACTOR_NAMES := {
	"factor_rage": "怒（暴怒因子）",
	"factor_fear": "惧（恐惧因子）",
	"factor_joy": "喜（欢愉因子）",
	"factor_sorrow": "哀（哀恸因子）",
}

var _shop_open: bool = false
var _frag_open: bool = false

func _ready() -> void:
	theme = UITheme.build_theme()
	_setup_background()
	_style()
	for i in range(1, 9):
		var btn: Button = get_node("ChaptersVBox/Chapter%d" % i)
		btn.pressed.connect(_on_chapter_pressed.bind(i))
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	frag_shop_button.pressed.connect(_on_frag_shop_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_update_ui()

func _setup_background() -> void:
	var bg := TextureRect.new()
	bg.texture = Placeholder.vertical_gradient(256, UITheme.BG_DEEP, Color("13132b"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	var orbs := FloatingBackground.new()
	orbs.orb_count = 16
	add_child(orbs)
	move_child(orbs, 1)
	var vig := TextureRect.new()
	vig.texture = Placeholder.vignette(256, 0.55, 0.85)
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

func _style() -> void:
	UITheme.label(title_label, 40, UITheme.CYAN, 7, 3)
	UITheme.label(cores_label, 22, UITheme.GOLD)
	UITheme.label(shards_label, 20, UITheme.PURPLE)
	UITheme.label(seed_label, 16, UITheme.TEXT_DIM)
	UITheme.label(shop_title, 30, UITheme.CYAN, 7, 3)
	UITheme.label(shop_body, 18, UITheme.TEXT)
	UITheme.label(fragment_title, 30, UITheme.PURPLE, 7, 3)
	UITheme.label(fragment_body, 18, UITheme.TEXT)
	shop_panel.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.04, 0.04, 0.09, 0.9), Color(0, 0, 0, 0), 0, 0, 0))
	shop_card.add_theme_stylebox_override("panel", UITheme.card_stylebox(UITheme.CYAN))
	fragment_panel.add_theme_stylebox_override("panel", UITheme.stylebox(Color(0.04, 0.04, 0.09, 0.9), Color(0, 0, 0, 0), 0, 0, 0))
	fragment_card.add_theme_stylebox_override("panel", UITheme.card_stylebox(UITheme.PURPLE))
	# 记忆碎片图标（素材缺失自动跳过）
	var frag_icon := Art.item_icon("memory_fragment")
	if frag_icon != null:
		var icon := TextureRect.new()
		icon.texture = frag_icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(22, 22)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shards_box.add_child(icon)
		shards_box.move_child(icon, 0)

func _update_ui() -> void:
	cores_label.text = "核心 ×%d" % MetaManager.cores
	shards_label.text = "记忆碎片 ×%d" % MetaManager.shards
	difficulty_button.text = "难度：%s" % RunManager.get_difficulty_name()
	for i in range(1, 9):
		var btn: Button = get_node("ChaptersVBox/Chapter%d" % i)
		btn.disabled = i > 1
		btn.text = "第 %d 章 · 暴怒" % i if i == 1 else "第 %d 章 · 未解锁" % i
		if i == 1:
			btn.add_theme_color_override("font_color", UITheme.RAGE)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_refresh_shop()
	_refresh_frag_shop()

func _on_chapter_pressed(chapter: int) -> void:
	var seed := 0
	var txt := seed_input.text.strip_edges()
	if txt.is_valid_int():
		seed = txt.to_int()
	GameManager.start_chapter(chapter, seed)

func _on_difficulty_pressed() -> void:
	RunManager.cycle_difficulty()
	_update_ui()

func _on_shop_pressed() -> void:
	_shop_open = true
	_refresh_shop()
	shop_panel.visible = true

func _on_frag_shop_pressed() -> void:
	_frag_open = true
	_refresh_frag_shop()
	fragment_panel.visible = true

func _on_back_pressed() -> void:
	GameManager.goto_main_menu()

func _refresh_shop() -> void:
	var lines: Array = []
	for i in MetaManager.UPGRADES.size():
		var u: Dictionary = MetaManager.UPGRADES[i]
		var lv := MetaManager.get_level(u["id"])
		var max_lv := int(u["max_level"])
		var cost := MetaManager.get_upgrade_cost(u["id"])
		var status := "（已满级）" if cost < 0 else "— %d 核心" % cost
		lines.append("%d. %s Lv.%d/%d %s（%s）" % [i + 1, u["name"], lv, max_lv, status, u["desc"]])
	shop_body.text = "\n".join(lines) + "\n\n按 1-%d 购买 · Esc 返回" % MetaManager.UPGRADES.size()

func _refresh_frag_shop() -> void:
	var lines: Array = ["◆ 禁用因子（%d/2 · 每个 %d 碎片，再按一次解禁退款）" % [MetaManager.get_ban_count(), MetaManager.BAN_COST], ""]
	for i in MetaManager.BANNABLE.size():
		var fid: String = MetaManager.BANNABLE[i]
		var state := "已禁" if MetaManager.is_banned(fid) else "未禁"
		lines.append("%d. %s [%s]" % [i + 1, FACTOR_NAMES.get(fid, fid), state])
	lines.append("")
	lines.append("5. 预设共鸣：%s（50 碎片解锁后循环切换）" % str(MetaManager.PRESETS.get(MetaManager.get_preset(), "无")))
	lines.append("")
	lines.append("记忆碎片：死亡/通关结算获得 · 死亡 = 5 + 阶段×2 · 通关 = 20 + 击杀×0.1")
	lines.append("")
	lines.append("按 1-5 操作 · Esc 返回")
	fragment_body.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _shop_open:
			_shop_open = false
			shop_panel.visible = false
		elif _frag_open:
			_frag_open = false
			fragment_panel.visible = false
		else:
			GameManager.goto_main_menu()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		var code := int(ke.keycode)
		if _shop_open and code >= int(KEY_1) and code <= int(KEY_9):
			var idx := code - int(KEY_1)
			if idx < MetaManager.UPGRADES.size():
				get_viewport().set_input_as_handled()
				MetaManager.buy_upgrade(str(MetaManager.UPGRADES[idx]["id"]))
				_update_ui()
		elif _frag_open and code >= int(KEY_1) and code <= int(KEY_5):
			get_viewport().set_input_as_handled()
			if code == int(KEY_5):
				MetaManager.cycle_preset()
			else:
				var idx := code - int(KEY_1)
				if idx < MetaManager.BANNABLE.size():
					MetaManager.toggle_ban(str(MetaManager.BANNABLE[idx]))
			_update_ui()
