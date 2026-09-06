class_name Art
extends RefCounted
## 集中加载 art/ 素材：路径映射 + 因子英文名 + 安全回退 + 统一缩放。
## 素材缺失时返回 null，调用方回退到 Placeholder 占位图。

const HERO_FRONT := "res://art/hero/hero_front.png"
const HERO_BACK := "res://art/hero/hero_back.png"

# factor_id -> 敌人目录名（注意：敌人目录用 anger，道具/地图前缀用 rage）
const ENEMY_DIR := {
	"factor_rage": "anger",
	"factor_joy": "joy",
	"factor_sorrow": "sorrow",
	"factor_fear": "fear",
	"factor_disgust": "disgust",
	"factor_surprise": "surprise",
	"factor_anxiety": "anxiety",
	"factor_chaos": "chaos",
}

# factor_id -> 道具/地图文件名前缀
const FACTOR_PREFIX := {
	"factor_rage": "rage",
	"factor_joy": "joy",
	"factor_sorrow": "sorrow",
	"factor_fear": "fear",
	"factor_disgust": "disgust",
	"factor_surprise": "surprise",
	"factor_anxiety": "anxiety",
	"factor_chaos": "chaos",
}

## 纹理缓存：按路径缓存（成功与失败都缓存，避免反复解码损坏文件）。
static var _cache: Dictionary = {}

## 安全加载纹理：直接读 PNG 原始文件（绕过导入管线），
## 文件缺失或损坏时返回 null，由调用方回退到占位图。
static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var result: Texture2D = null
	var img := Image.new()
	if img.load(path) == OK:
		result = ImageTexture.create_from_image(img)
	_cache[path] = result
	return result

## 把精灵按目标像素尺寸等比缩放（以长边为准）。
static func fit_sprite(spr: Sprite2D, texture: Texture2D, target_px: float) -> void:
	if spr == null or texture == null:
		return
	spr.texture = texture
	var longest := maxf(float(texture.get_width()), float(texture.get_height()))
	if longest <= 0.0:
		return
	spr.scale = Vector2.ONE * (target_px / longest)

# ---- 英雄 ----
static func hero_front() -> Texture2D:
	return tex(HERO_FRONT)

static func hero_back() -> Texture2D:
	return tex(HERO_BACK)

# ---- 敌人 ----
static func enemy_mob(factor_id: String, variant: int) -> Texture2D:
	var dir: String = ENEMY_DIR.get(factor_id, "anger")
	return tex("res://art/enemies/%s/%s_mob%d.png" % [dir, dir, variant])

static func enemy_boss(factor_id: String) -> Texture2D:
	var dir: String = ENEMY_DIR.get(factor_id, "anger")
	return tex("res://art/enemies/%s/%s_boss.png" % [dir, dir])

# ---- 道具 ----
static func essence(factor_id: String) -> Texture2D:
	var p: String = FACTOR_PREFIX.get(factor_id, "rage")
	return tex("res://art/items/essence_%s.png" % p)

static func energy(factor_id: String) -> Texture2D:
	var p: String = FACTOR_PREFIX.get(factor_id, "rage")
	return tex("res://art/items/energy_%s.png" % p)

static func coin() -> Texture2D:
	return tex("res://art/items/coin.png")

static func stabilizer() -> Texture2D:
	return tex("res://art/items/stabilizer.png")

# ---- 地图 ----
static func map_texture(factor_id: String) -> Texture2D:
	var p: String = FACTOR_PREFIX.get(factor_id, "rage")
	var t := tex("res://art/maps/%s_map.png" % p)
	if t == null:
		t = tex("res://art/maps/base_map.png")
	return t

static func base_map() -> Texture2D:
	return tex("res://art/maps/base_map.png")
