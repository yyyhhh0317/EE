class_name Pickup
extends Area2D
## 掉落物：因子精华（怒/惧）或稳定剂，玩家触碰拾取。
## 视觉：菱形宝石 + 辉光底 + 旋转/呼吸动画。

var pickup_type: String = "factor_rage"
var _glow: Sprite2D
var _animated: bool = false
var _use_placeholder: bool = true

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
	var tex: Texture2D
	match pickup_type:
		"factor_rage":
			tex = Art.essence("factor_rage")
			c = Color(0.95, 0.42, 0.26)
		"factor_fear":
			tex = Art.essence("factor_fear")
			c = Color(0.63, 0.42, 0.92)
		"stabilizer":
			tex = Art.stabilizer()
			c = Color(0.42, 0.9, 0.62)
	if _glow == null:
		_glow = Sprite2D.new()
		_glow.texture = Placeholder.soft_glow(16, Color.WHITE)
		add_child(_glow)
		move_child(_glow, 0)
	_glow.modulate = Color(c.r, c.g, c.b, 0.45)
	if tex != null:
		Art.fit_sprite(body_sprite, tex, 26.0)
		body_sprite.modulate = Color.WHITE
		body_sprite.rotation = 0.0
		_use_placeholder = false
	else:
		body_sprite.texture = Placeholder.gem(9, Color.WHITE)
		body_sprite.modulate = c
		body_sprite.rotation = 0.0
		_use_placeholder = true
	if not _animated:
		_animate()

func _animate() -> void:
	_animated = true
	if _glow != null:
		_glow.scale = Vector2(0.9, 0.9)
		var gt := create_tween().set_loops()
		gt.tween_property(_glow, "scale", Vector2(1.22, 1.22), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gt.tween_property(_glow, "scale", Vector2(0.9, 0.9), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _use_placeholder and body_sprite != null:
		var rt := create_tween().set_loops()
		rt.tween_property(body_sprite, "rotation", TAU, 3.0)

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
				color = Color(0.95, 0.42, 0.26)
			else:
				text = "+1 惧精华"
				color = Color(0.63, 0.42, 0.92)
		"stabilizer":
			RunManager.use_stabilizer()
			text = "-20 失控"
			color = Color(0.42, 0.9, 0.62)
	EventBus.emit("fx.float_text", {"text": text, "pos": pos, "color": color})
	queue_free()
