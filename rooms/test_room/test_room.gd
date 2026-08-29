extends Node2D
## 测试房间（M0 骨架）：空场景占位，验证「主菜单 → 空场景 → 返回」。

func _ready() -> void:
	print("[TestRoom] 已进入测试房间（M0 骨架）。")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameManager.back_to_menu()
