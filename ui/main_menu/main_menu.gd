extends Control
## 主菜单占位界面。

@onready var _start_button: Button = $VBox/StartButton
@onready var _quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	GameManager.goto_lobby()

func _on_quit_pressed() -> void:
	GameManager.quit_game()
