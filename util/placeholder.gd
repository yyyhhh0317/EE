class_name Placeholder
extends RefCounted
## 无美术资源时的占位纹理生成（M1 原型用，后续替换为真实素材）。
## M5 视觉升级：光球 / 尖刺怪 / 宝石 / 光环 / 软辉光 / 网格 / 暗角 / 渐变。

static var _cache: Dictionary = {}

## 生成实心圆（带抗锯齿边缘，兼容旧调用）。
static func circle(radius: int, color: Color) -> Texture2D:
	return _cached("circle_%d_%s" % [radius, color.to_html()], func() -> Texture2D:
		var pad := 2
		var size := radius * 2 + pad * 2 + 1
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := radius + pad
		for y in size:
			for x in size:
				var d := Vector2(x - c, y - c).length()
				var a := clampf(radius - d + 0.5, 0.0, 1.0)
				a = minf(a, 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
		return ImageTexture.create_from_image(img)
	)

## 光球：径向明暗 + 暗边 + 高光（玩家/能量体）。
static func orb(radius: int, color: Color) -> Texture2D:
	return _cached("orb_%d_%s" % [radius, color.to_html()], func() -> Texture2D:
		var pad := 3
		var size := radius * 2 + pad * 2 + 1
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := radius + pad
		for y in size:
			for x in size:
				var dx := x - c
				var dy := y - c
				var d := sqrt(dx * dx + dy * dy)
				if d <= radius:
					var t := d / float(radius)
					var col := color.lerp(color.darkened(0.55), t)
					# 顶部受光
					col = col.lightened((1.0 - t) * 0.12)
					# 左上高光
					var hx := x - (c - radius * 0.38)
					var hy := y - (c - radius * 0.42)
					var hd := sqrt(hx * hx + hy * hy)
					if hd < radius * 0.30:
						col = col.lerp(Color(1, 1, 1, 0.95), 1.0 - hd / (radius * 0.30))
					img.set_pixel(x, y, col)
				elif d <= radius + 1.2:
					img.set_pixel(x, y, color.darkened(0.78))
		return ImageTexture.create_from_image(img)
	)

## 尖刺怪：N 角星形 + 径向明暗（敌人/狂化体）。
static func spiky(radius: int, color: Color, spikes: int = 8) -> Texture2D:
	return _cached("spiky_%d_%d_%s" % [radius, spikes, color.to_html()], func() -> Texture2D:
		var pad := 4
		var size := radius * 2 + pad * 2 + 1
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := radius + pad
		for y in size:
			for x in size:
				var dx := x - c
				var dy := y - c
				var d := sqrt(dx * dx + dy * dy)
				if d < 0.01:
					img.set_pixel(x, y, color)
					continue
				var ang := atan2(dy, dx)
				# 尖刺半径：0.66r（谷）~ r（尖）
				var r_out := radius * (0.66 + 0.34 * absf(cos(spikes * ang * 0.5)))
				if d <= r_out:
					var t := d / float(r_out)
					var col := color.lerp(color.darkened(0.6), t)
					# 朝外尖角略亮
					col = col.lightened(0.06 * (1.0 - t))
					img.set_pixel(x, y, col)
				elif d <= r_out + 1.4:
					img.set_pixel(x, y, color.darkened(0.8))
		return ImageTexture.create_from_image(img)
	)

## 宝石：菱形 + 切面（因子精华/掉落物）。
static func gem(size: int, color: Color) -> Texture2D:
	return _cached("gem_%d_%s" % [size, color.to_html()], func() -> Texture2D:
		var pad := 3
		var w := size * 2 + pad * 2 + 1
		var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
		var c := size + pad
		for y in w:
			for x in w:
				var nx := absf(float(x - c)) / float(size)
				var ny := absf(float(y - c)) / float(size * 1.15)
				if nx + ny <= 1.0:
					var up := 1.0 - (y / float(w))  # 上亮下暗
					var col := color.lightened(0.25 * up).darkened(0.25 * (1.0 - up))
					# 顶部高光点
					var hx := x - (c - size * 0.18)
					var hy := y - (c - size * 0.32)
					if sqrt(hx * hx + hy * hy) < size * 0.22:
						col = col.lerp(Color(1, 1, 1, 0.95), 0.7)
					img.set_pixel(x, y, col)
				elif nx + ny <= 1.08:
					img.set_pixel(x, y, color.darkened(0.7))
		return ImageTexture.create_from_image(img)
	)

## 光环（圆环描边）。
static func ring(radius: int, thickness: int, color: Color) -> Texture2D:
	return _cached("ring_%d_%d_%s" % [radius, thickness, color.to_html()], func() -> Texture2D:
		var pad := thickness + 1
		var size := radius * 2 + pad * 2 + 1
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := radius + pad
		var r_in := radius - thickness
		for y in size:
			for x in size:
				var d := Vector2(x - c, y - c).length()
				if d <= radius and d >= r_in:
					var a := clampf(minf(radius - d + 0.5, d - r_in + 0.5), 0.0, 1.0)
					img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
		return ImageTexture.create_from_image(img)
	)

## 软辉光：中心不透明 → 边缘透明（投射物/光环/爆发）。
static func soft_glow(radius: int, color: Color) -> Texture2D:
	return _cached("glow_%d_%s" % [radius, color.to_html()], func() -> Texture2D:
		var size := radius * 2 + 1
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := radius
		for y in size:
			for x in size:
				var d := Vector2(x - c, y - c).length() / float(radius)
				if d < 1.0:
					var a := pow(1.0 - d, 2.0)
					img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
		return ImageTexture.create_from_image(img)
	)

## 网格单元贴图（用于平铺的竞技场地板）。
static func grid_cell(cell: int, color: Color) -> Texture2D:
	return _cached("grid_%d_%s" % [cell, color.to_html()], func() -> Texture2D:
		var img := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		for i in cell:
			img.set_pixel(i, 0, color)
			img.set_pixel(0, i, color)
		return ImageTexture.create_from_image(img)
	)

## 暗角：中心透明 → 四角变暗。
static func vignette(size: int, inner: float, outer: float) -> Texture2D:
	return _cached("vign_%d_%s_%s" % [size, str(inner), str(outer)], func() -> Texture2D:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := size * 0.5
		var rmax := size * 0.71
		for y in size:
			for x in size:
				var d := Vector2(x - c, y - c).length() / rmax
				var a := clampf(remap(d, inner, 1.0, 0.0, outer), 0.0, outer)
				img.set_pixel(x, y, Color(0, 0, 0, a))
		return ImageTexture.create_from_image(img)
	)

## 竖直渐变（菜单/大厅背景）。
static func vertical_gradient(h: int, top: Color, bottom: Color) -> Texture2D:
	return _cached("grad_%d_%s_%s" % [h, top.to_html(), bottom.to_html()], func() -> Texture2D:
		var img := Image.create(2, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var col := top.lerp(bottom, y / float(h - 1))
			img.set_pixel(0, y, col)
			img.set_pixel(1, y, col)
		return ImageTexture.create_from_image(img)
	)

static func _cached(key: String, gen: Callable) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = gen.call()
	_cache[key] = tex
	return tex
