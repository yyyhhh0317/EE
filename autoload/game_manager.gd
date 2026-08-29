extends Node
## GameManager —— 顶层游戏流程状态机。
##
## 状态：BOOT → MAIN_MENU → RUN → GAME_OVER / VICTORY → ...
## 单例之间也通过 EventBus 通信；本类只做编排，具体逻辑下沉到对应系统。

enum State { BOOT, MAIN_MENU, RUN, GAME_OVER, VICTORY, META }

const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const TEST_ROOM_SCENE := "res://rooms/test_room/test_room.tscn"

var current_state: State = State.BOOT

func _ready() -> void:
	# Autoload 已按顺序初始化（EventBus / DataManager 等），此处进入主菜单。
	change_state(State.MAIN_MENU)

func change_state(new_state: State) -> void:
	current_state = new_state
	EventBus.emit("game.state_changed", new_state)
	print("[GameManager] 状态 → ", State.keys()[new_state])

## 从主菜单开始新的一局（当前先进入测试房间，M3 替换为正式关卡）。
func start_run() -> void:
	RunManager.start_run()
	change_state(State.RUN)
	SceneManager.goto(TEST_ROOM_SCENE)

## 返回主菜单。
func back_to_menu() -> void:
	RunManager.end_run()
	change_state(State.MAIN_MENU)
	SceneManager.goto(MENU_SCENE)

## 退出游戏。
func quit_game() -> void:
	get_tree().quit()
