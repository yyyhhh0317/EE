extends Node
## GameManager —— 顶层游戏流程状态机。
##
## 状态：BOOT → MAIN_MENU → RUN → GAME_OVER / VICTORY → ...
## 单例之间也通过 EventBus 通信；本类只做编排，具体逻辑下沉到对应系统。

enum State { BOOT, MAIN_MENU, RUN, GAME_OVER, VICTORY, META }

const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const RUN_SCENE := "res://run/run.tscn"

var current_state: State = State.BOOT

func _ready() -> void:
	# Autoload 已按顺序初始化（EventBus / DataManager 等），此处进入主菜单。
	_setup_window()
	change_state(State.MAIN_MENU)

## 全屏运行（画面铺满整个屏幕，配合 canvas_items 拉伸等比放大）。
func _setup_window() -> void:
	get_window().mode = Window.MODE_FULLSCREEN

func change_state(new_state: State) -> void:
	current_state = new_state
	EventBus.emit("game.state_changed", new_state)
	print("[GameManager] 状态 → ", State.keys()[new_state])

## 从主菜单开始新的一局。
func start_run() -> void:
	RunManager.start_run()
	change_state(State.RUN)
	SceneManager.goto(RUN_SCENE)

## 返回主菜单。
func back_to_menu() -> void:
	RunManager.end_run()
	change_state(State.MAIN_MENU)
	SceneManager.goto(MENU_SCENE)

## 退出游戏。
func quit_game() -> void:
	get_tree().quit()
