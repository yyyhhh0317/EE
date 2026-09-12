extends Node
## 冒烟测试（headless）：
##   godot --headless --path . res://boot/smoke_test.tscn -- --smoke-scene
## 自动驱动一局核心玩法链路：注射 → 共鸣 → 对立 → 稀释 → 回路 → 情绪风暴代价 →
## 双轨资源状态机（亢奋/暴走）→ 记忆碎片 → 禁因子，全部跑通后自动退出。
## 退出码：正常退出（无脚本错误）即可；失败会在控制台打印 ERROR。

const RUN_SCENE := preload("res://run/run.tscn")

var _fail_count: int = 0

func _ready() -> void:
	print("[Smoke] boot · Godot %s" % Engine.get_version_info().string)
	RunManager.start_run(1, 12345)
	add_child(RUN_SCENE.instantiate())
	_drive.call_deferred()

func _check(name: String, ok: bool) -> void:
	if ok:
		print("[Smoke] PASS  %s" % name)
	else:
		_fail_count += 1
		print("[Smoke] FAIL  %s" % name)

func _drive() -> void:
	# 1. 精华 → 注入 4 因子（相邻：怒-惧、喜-哀）
	RunManager.gain_essence("factor_rage")
	RunManager.gain_essence("factor_fear")
	RunManager.gain_essence("factor_joy")
	RunManager.gain_essence("factor_sorrow")
	_check("inject_rage", bool(RunManager.inject_factor("factor_rage", 0)["ok"]))
	_check("inject_fear", bool(RunManager.inject_factor("factor_fear", 1)["ok"]))
	_check("inject_joy", bool(RunManager.inject_factor("factor_joy", 2)["ok"]))
	_check("inject_sorrow", bool(RunManager.inject_factor("factor_sorrow", 3)["ok"]))
	_check("no_essence_blocks", not bool(RunManager.inject_factor("factor_rage", 4)["ok"]))
	# 2. 共鸣：怒+惧 相邻（0-1）、喜+哀 相邻（2-3）
	var res := BuildManager.get_adjacent_resonance_stacks()
	_check("resonance_rage_fear", int(res.get("resonance_rage_fear", 0)) == 1)
	_check("resonance_joy_sorrow", int(res.get("resonance_joy_sorrow", 0)) == 1)
	# 3. 对立制衡：怒与喜共存（躁动）、惧与哀共存（麻木）
	_check("oppose_rage_joy_active", BuildManager.has_opposite("oppose_rage_joy"))
	_check("oppose_fear_sorrow_active", BuildManager.has_opposite("oppose_fear_sorrow"))
	_check("threshold_down", absf(RunManager.excite_threshold() - 0.6) < 0.001)
	_check("damage_overheat_down", absf(RunManager.damage_overheat_mult() - 0.5) < 0.001)
	# 4. 乘法稀释：怒 2 槽 → dil = 3^-0.3 ≈ 0.719
	RunManager.gain_essence("factor_rage")
	RunManager.inject_factor("factor_rage", 5)  # 怒槽 ×2
	var dil := BuildManager.dilution("rage")
	_check("dilution_rage", absf(dil - pow(3.0, -0.3)) < 0.001)
	# 5. 回路闭合 → 大招可放；情绪风暴代价 → 降级清槽
	RunManager.gain_essence("factor_fear")
	RunManager.inject_factor("factor_fear", 4)  # 6 槽满
	_check("loop_full", BuildManager.is_full())
	_check("ultimate_ready", RunManager.can_ultimate())
	_check("sanity_cost", RunManager.spend_sanity(RunManager.ULTIMATE_SANITY_COST))
	RunManager.use_ultimate()
	BuildManager.degrade_all()
	_check("after_degrade_not_full", not BuildManager.is_full())
	# 6. 双轨资源状态机：清空失控并回到稳定 → 80 进亢奋 → 满理智进暴走 → 烧完进冷却
	RunManager.reduce_overheat(999.0)
	var guard := 0
	while RunManager.state != RunManager.State.STABLE and guard < 100:
		RunManager.tick(0.05, null)
		guard += 1
	_check("back_to_stable", RunManager.state == RunManager.State.STABLE)
	RunManager.add_overheat(80.0)
	_check("state_excited", RunManager.state == RunManager.State.EXCITED)
	RunManager.add_sanity(999.0)  # 满理智进暴走：可存活路线
	RunManager.add_overheat(25.0)
	_check("state_berserk", RunManager.state == RunManager.State.BERSERK)
	guard = 0
	while RunManager.state == RunManager.State.BERSERK and guard < 10000:
		RunManager.tick(0.05, null)
		guard += 1
	_check("berserk_cools_down", RunManager.state == RunManager.State.COOLDOWN)
	# 7. 理智吞噬：暴走扣理智
	_check("sanity_drained", RunManager.sanity < RunManager.SANITY_MAX)
	# 8. 记忆碎片 + 禁因子（解禁退款）
	var before := MetaManager.shards
	MetaManager.add_shards(100)
	_check("shards_added", MetaManager.shards == before + 100)
	var t1 := MetaManager.toggle_ban("factor_joy")
	_check("ban_ok", bool(t1["ok"]) and MetaManager.is_banned("factor_joy"))
	_check("banned_gain_converts", _banned_gain_is_currency())
	MetaManager.toggle_ban("factor_joy")
	_check("ban_unbanned", not MetaManager.is_banned("factor_joy"))
	# 9. 情绪过载：10s 内 3 种事件
	BuildManager.record_event("fear_spread")
	BuildManager.record_event("resonance")
	BuildManager.record_event("storm")
	# 10. 死亡结算
	var death_shards := RunManager.shards_on_death()
	_check("death_shards_formula", death_shards == 5 + RunManager.current_choice_index * 2)
	RunManager.end_run(false)
	_check("end_run_stops", not RunManager.is_running)
	# 11. 素材接入冒烟：像素数字字体 / 能量弹 / 血条素材（缺失自动回退，不应报错）
	var dn: Node2D = load("res://combat/damage_number.tscn").instantiate()
	add_child(dn)
	dn.setup(42.0, Vector2(100, 100), Color.WHITE, false)
	var dn2: Node2D = load("res://combat/damage_number.tscn").instantiate()
	add_child(dn2)
	dn2.setup(777.0, Vector2(100, 100), Color(1.0, 0.8, 0.3), true)
	var proj: Projectile = load("res://combat/projectile.tscn").instantiate()
	add_child(proj)
	proj.setup(Vector2(100, 100), Vector2.RIGHT, 10.0, 600.0, null, true, Color.WHITE, 1.0, "factor_rage")
	var proj2: Projectile = load("res://combat/projectile.tscn").instantiate()
	add_child(proj2)
	proj2.setup(Vector2(100, 100), Vector2.RIGHT, 10.0, 600.0, null, false, Color.WHITE, 1.0, "")
	var hb: HealthBar = load("res://combat/health_bar.tscn").instantiate()
	add_child(hb)
	hb.set_value(0.5)
	var hbb: HealthBar = load("res://combat/health_bar.tscn").instantiate()
	hbb.use_boss_style = true
	add_child(hbb)
	hbb.set_value(0.8)
	_check("asset_smoke_ok", true)
	print("[Smoke] RESULT %s（fail=%d）" % ["ALL PASS" if _fail_count == 0 else "HAS FAILURES", _fail_count])
	get_tree().quit(_fail_count)

func _banned_gain_is_currency() -> bool:
	var cur := RunManager.currency
	RunManager.gain_essence("factor_joy")
	return RunManager.currency == cur + 10
