class_name Pickup
extends Area2D
## 掉落物：因子精华（怒/惧）或稳定剂，玩家触碰拾取。

var pickup_type: String = "factor_rage"

@onready var body_sprite: Sprite2D = $Body

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()

func setup(type: String, pos: Vector2) -> void:
	pickup_type = type
	global_position = pos
	_apply_visual()

func _apply_visual() -> void:
	var c := Color.WHITE
	match pickup_type:
		"factor_rage":
			c = Color(0.95, 0.4, 0.25)
		"factor_fear":
			c = Color(0.6, 0.4, 0.9)
		"stabilizer":
			c = Color(0.4, 0.9, 0.6)
	body_sprite.texture = Placeholder.circle(9, Color.WHITE)
	body_sprite.modulate = c

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var pos := global_position
	var text := ""
	var color := Color.WHITE
	match pickup_type:
		"factor_rage", "factor_fear":
			RunManager.gain_essence(pickup_type)
			if pickup_type == "factor_rage":
				text = "+1 怒精华"
				color = Color(0.95, 0.4, 0.25)
			else:
				text = "+1 惧精华"
				color = Color(0.6, 0.4, 0.9)
		"stabilizer":
			RunManager.use_stabilizer()
			text = "-20 失控"
			color = Color(0.4, 0.9, 0.6)
	EventBus.emit("fx.float_text", {"text": text, "pos": pos, "color": color})
	queue_free()
