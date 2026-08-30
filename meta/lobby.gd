extends Control
## 大厅（局外 Hub）：选章节 + 难度 + 种子 + 商店（meta 强化）+ 返回主菜单。

@onready var cores_label: Label = $CoresLabel
@onready var difficulty_button: Button = $BottomButtons/DifficultyButton
@onready var shop_button: Button = $BottomButtons/ShopButton
@onready var back_button: Button = $BottomButtons/BackButton
@onready var seed_input: LineEdit = $SeedBox/SeedInput
@onready var shop_panel: ColorRect = $ShopPanel
@onready var shop_body: Label = $ShopPanel/ShopBody

var _shop_open: bool = false

func _ready() -> void:
	for i in range(1, 9):
		var btn: Button = get_node("ChaptersVBox/Chapter%d" % i)
		btn.pressed.connect(_on_chapter_pressed.bind(i))
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_update_ui()

func _update_ui() -> void:
	cores_label.text = "核心 ×%d" % MetaManager.cores
	difficulty_button.text = "难度：%s" % RunManager.get_difficulty_name()
	for i in range(1, 9):
		var btn: Button = get_node("ChaptersVBox/Chapter%d" % i)
		btn.disabled = i > 1
		btn.text = "第 %d 章 · 暴怒" % i if i == 1 else "第 %d 章 · 未解锁" % i
	_refresh_shop()

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _shop_open:
			_shop_open = false
			shop_panel.visible = false
		else:
			GameManager.goto_main_menu()
	elif _shop_open and event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		var code := int(ke.keycode)
		if code >= int(KEY_1) and code <= int(KEY_9):
			var idx := code - int(KEY_1)
			if idx < MetaManager.UPGRADES.size():
				get_viewport().set_input_as_handled()
				MetaManager.buy_upgrade(str(MetaManager.UPGRADES[idx]["id"]))
				_update_ui()
