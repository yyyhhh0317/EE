extends Control
## 主菜单：标题 + 开始/退出 + 渐变背景 + 漂浮因子光球 + 暗角。

@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _version: Label = $Version
@onready var _start_button: Button = $VBox/StartButton
@onready var _quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	theme = UITheme.build_theme()
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_setup_background()
	_style()
	_animate_title()

func _setup_background() -> void:
	var bg := TextureRect.new()
	bg.texture = Placeholder.vertical_gradient(256, UITheme.BG_DEEP, Color("141428"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	var orbs := FloatingBackground.new()
	orbs.orb_count = 18
	add_child(orbs)
	move_child(orbs, 1)
	var vig := TextureRect.new()
	vig.texture = Placeholder.vignette(256, 0.55, 0.9)
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

func _style() -> void:
	UITheme.label(_title, 64, UITheme.CYAN, 8, 4)
	UITheme.label(_subtitle, 18, UITheme.TEXT_DIM)
	UITheme.label(_version, 13, UITheme.TEXT_DIM, 3, 1)
	_start_button.custom_minimum_size = Vector2(240, 52)
	_quit_button.custom_minimum_size = Vector2(240, 52)

func _animate_title() -> void:
	_title.modulate = Color(0.72, 0.9, 1.0)
	var tween := create_tween().set_loops()
	tween.tween_property(_title, "modulate", UITheme.CYAN, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "modulate", Color(0.72, 0.9, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start_pressed() -> void:
	GameManager.goto_lobby()

func _on_quit_pressed() -> void:
	GameManager.quit_game()
