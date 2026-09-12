class_name Pickup
extends Area2D
## 掉落物：因子精华（怒/惧）或稳定剂，玩家触碰拾取。
## 视觉：菱形宝石 + 辉光底 + 旋转/呼吸动画。

var pickup_type: String = "factor_rage"
var _glow: Sprite2D
var _animated: bool = false
var _use_placeholder: bool = true

@onready var body_sprite: Sprite2D = $Body

const STABILIZER_COLOR := Color(0.42, 0.9, 0.62)   # 非因子道具，颜色自持
const SHORT_NAME := {
	"factor_rage": "怒", "factor_fear": "惧", "factor_joy": "喜", "factor_sorrow": "哀",
	"factor_disgust": "厌", "factor_surprise": "惊", "factor_anxiety": "忧", "factor_chaos": "混沌",
}


## 显示 / 辉光颜色：因子一律取数据表 color（唯一色源），非因子道具用本地常量。
func display_color(id: String) -> Color:
	if id == "stabilizer":
		return STABILIZER_COLOR
	var f := DataManager.get_factor(id)
	if f.is_empty():
		return Color.WHITE
	return Color(str(f.get("color", "#ffffff")))


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()

func setup(type: String, pos: Vector2) -> void:
	pickup_type = type
	global_position = pos
	_apply_visual()

func _apply_visual() -> void:
	var c := display_color(pickup_type)
	var tex: Texture2D
	if pickup_type == "stabilizer":
		tex = Art.stabilizer()
	else:
		tex = Art.essence(pickup_type)
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
	match pickup_type:
		"factor_rage", "factor_fear", "factor_joy", "factor_sorrow":
			RunManager.gain_essence(pickup_type)
			text = "+1 %s精华" % SHORT_NAME.get(pickup_type, "")
		"stabilizer":
			RunManager.use_stabilizer()
			text = "-20 失控"
	# 颜色统一从数据表取（唯一色源），不再硬编码
	EventBus.emit("fx.float_text", {"text": text, "pos": pos, "color": display_color(pickup_type)})
	queue_free()
