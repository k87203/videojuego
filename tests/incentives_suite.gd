extends Node
const Course = preload("res://scripts/expansion_data.gd")
const Collection = preload("res://scripts/campus_collection.gd")
var app
var count := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func ticks(n: int = 3) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame

func _ready() -> void:
	Progress.session_only = true
	Progress.reset_data()
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await ticks()
	check(Progress.credit(120, "ex_1_1_credit_280"), "A stable reward deposits coins")
	check(not Progress.credit(120, "ex_1_1_credit_280") and Progress.data.wallet == 120, "The same reward cannot pay twice")
	check(not Progress.buy("invalid") and Progress.data.wallet == 120, "Unknown purchases do not spend coins")
	check(Progress.buy("heart") and Progress.data.wallet == 40, "The health upgrade deducts its exact price")
	check(not Progress.buy("heart") and Progress.data.wallet == 40, "The health upgrade cannot be stacked")
	check(not Progress.buy("cap") or Progress.data.wallet == 15, "An affordable accessory has its stated price")
	check(not Progress.buy("mint") and Progress.data.wallet == 15, "Insufficient funds cannot buy a skin")
	check(Progress.equip("alex", "accessory", "cap"), "Owned accessories can be equipped")
	check(not Progress.equip("valeria", "skin", "mint"), "Unowned cosmetics cannot be equipped")
	check(Progress.outfit("valeria").is_empty(), "Outfits are independent for each student")
	Progress.credit(30, "ex_1_2_credit_280")
	check(Progress.buy("mint") and Progress.equip("alex", "skin", "mint"), "A purchased skin can be equipped alongside an accessory")
	Progress.complete(1, "A", 250, 0)
	Progress.complete(1, "B", 270, 3)
	check(Progress.data.best["1"] == "A" and Progress.data.times["1"] == 250, "Worse runs do not replace records")
	Progress.complete(1, "S", 230, 1)
	check(Progress.data.best["1"] == "S" and Progress.data.times["1"] == 230, "Better grade and time update independently")
	check(Progress.data.achievements.has("honors") and Progress.data.achievements.has("speed") and Progress.data.achievements.has("untouched"), "Performance unlocks permanent achievements")
	Progress.new_game()
	check(Progress.data.wallet == 15 and "heart" in Progress.data.purchases and Progress.data.best["1"] == "S", "New adventures retain wallet, purchases and records")
	check(not Progress.credit(120, "ex_1_1_credit_280"), "New adventures cannot farm previous coin rewards")
	check(Progress.data.unlocked == 1 and Progress.data.fragments.is_empty(), "Campaign progression still resets")
	for character in ["alex", "valeria", "diego", "sofia"]:
		Progress.data.character = character
		app.start_level(3)
		await ticks()
		var w = app.world
		var p = w.player
		var base := int(p.character.health)
		check(p.max_health == base + 1, "%s gains exactly one exploration heart" % character)
		w.activate_arena()
		check(p.max_health == base and p.health <= base, "%s enters bosses with original health" % character)
		check(w.boss.max_health == 6, "Purchases preserve BUG 404 health")
		w.respawn()
		check(p.max_health == base + 1 and p.health == p.max_health, "%s respawns with exploration health" % character)
		app.start_level(4)
		await ticks()
		w = app.world
		w.activate_arena()
		check(w.player.max_health == base and w.boss.max_health == 12, "%s preserves final boss health limits" % character)
	var enemy_id := Progress.reward_id(4, 93000, "minion_phase3")
	check(Progress.award_score(enemy_id, 150) and not Progress.award_score(enemy_id, 150), "Repeated boss summons share one persistent reward per phase")
	for level in [1, 2, 3, 4]:
		app.start_level(level)
		await ticks()
		var w = app.world
		w.set_process(false)
		w.extension.set_process(false)
		var found: Array = []
		for index in [1, 21, 65]:
			var x: int = Course.START + int(index) * Course.CHUNK
			w.extension.sync_chunks(x)
			await ticks()
			var relic
			for prop in w.all_props():
				if prop.world == w and prop.kind == "relic" and not prop.is_queued_for_deletion() and prop.position.x == x + 1050: relic = prop
			check(is_instance_valid(relic), "Level %d chunk %d contains its hidden relic" % [level, index])
			if not is_instance_valid(relic): continue
			check(relic.uid == "ex_%d_%d_relic_1050" % [level, index] and relic.hidden_reward, "Relic ID includes level, chunk and local position")
			found.append(relic.uid)
			relic.collect()
			check(not Progress.collect_relic(relic.uid), "A collected relic cannot award score twice")
		check(found.size() == 3 and Progress.relic_count(level) == 3, "Level %d unlocks its gallery print" % level)
		w.extension.sync_chunks(Course.START + 35 * Course.CHUNK)
		await ticks()
		w.extension.sync_chunks(Course.START + Course.CHUNK)
		await ticks()
		for prop in w.all_props():
			if prop.world == w and prop.kind == "relic" and not prop.is_queued_for_deletion(): check(prop.collected, "Streaming does not respawn a collected relic")
	check(Progress.data.relics.size() == 12 and "collector" in Progress.data.achievements, "Twelve unique relics unlock the collection achievement")
	app.show_menu()
	for tab in ["shop", "gallery", "records"]:
		Collection.build(app, tab)
		await ticks()
		check(app.screen == "collection" and app.ui.get_child_count() > 4, "The %s screen builds" % tab)
	Collection.gallery_page(app, 4)
	await ticks()
	check(app.ui.get_child_count() > 3, "Unlocked gallery artwork opens")
	await shop_characters()
	await persistence()
	print("INCENTIVES RESULT: %d checks, %d failures" % [count, failures])
	app.queue_free()
	Sound.shutdown()
	await ticks()
	await get_tree().create_timer(0.2).timeout
	OS.delay_msec(250)
	get_tree().quit(1 if failures else 0)

func control_with_meta(key: String, value: String):
	for node in app.ui.get_children():
		if node.get_meta(key, "") == value: return node
	return null

func shop_characters() -> void:
	var previous: Dictionary = Progress.data.duplicate(true)
	Progress.reset_data()
	check(not Progress.select_character("maestra_luz") and not Progress.select_character("profe_nico"), "Both teachers are locked before purchase")
	check(not Progress.equip("maestra_luz", "skin", ""), "Locked teachers cannot be equipped through another path")
	Collection.build(app, "gallery")
	await ticks()
	var visible_locked := 0
	for node in app.ui.get_children():
		if node.get_script() == preload("res://scripts/gallery_art.gd") and node.locked: visible_locked += 1
	check(visible_locked == 4, "All four locked gallery illustrations remain visible with padlocks")
	var gallery_nodes: int = app.ui.get_child_count()
	Collection.gallery_page(app, 1)
	check(app.ui.get_child_count() == gallery_nodes, "Previewing a locked illustration does not unlock its full page")
	app.character_select(false)
	await ticks()
	var choices := 0
	for node in app.ui.get_children():
		if node.has_meta("character_choice"): choices += 1
	check(choices == 6 and control_with_meta("character_choice", "maestra_luz").disabled, "Character selection shows six portraits and locks unowned teachers")
	Collection.build(app, "shop")
	await ticks()
	var previews: Array = []
	for node in app.ui.get_children():
		if node.has_meta("shop_product"): previews.append(str(node.get_meta("shop_product")))
	check(previews.size() == Progress.SHOP.size(), "Every shop product has a dedicated image")
	var preview = control_with_meta("shop_product", "sunset")
	check(preview.get_child(0).preview_outfit.skin == "sunset", "Unowned skin previews display the offered color")
	preview = control_with_meta("shop_product", "cap")
	check(preview.get_child(0).preview_outfit.accessory == "cap", "Accessory previews display the offered item")
	check(Progress.data.wallet == 0 and Progress.data.purchases.is_empty() and Progress.data.equipment.is_empty(), "Browsing images neither buys nor equips products")
	check(control_with_meta("shop_buy", "maestra_luz").disabled, "Teacher purchase is disabled without enough coins")
	Progress.credit(240, "ex_1_3_credit_500")
	for teacher in ["maestra_luz", "profe_nico"]:
		Collection.build(app, "shop")
		await ticks()
		var buy = control_with_meta("shop_buy", teacher)
		var balance := int(Progress.data.wallet)
		buy.pressed.emit()
		await ticks()
		check(Progress.data.wallet == balance - 120 and Progress.data.character == teacher, "Buying %s through the shop deducts 120 coins and selects them" % teacher)
		check(not Progress.buy(teacher), "Owned teachers cannot be charged twice")
		app.character_select(false)
		await ticks()
		check(not control_with_meta("character_choice", teacher).disabled, "Purchased teacher appears unlocked in character selection")
		app.start_level(1)
		await ticks()
		var p = app.world.player
		check(p.character_id == teacher and p.max_health == 3, "Purchased teacher is playable with three hearts")
		p.use_ability()
		check(p.dash_time > 0 if teacher == "maestra_luz" else p.radar_time > 0, "Teacher Q ability uses the established gameplay effect")
	check(Progress.data.purchases.size() == 2, "Both purchased teachers remain owned after gameplay")
	Progress.new_game()
	check(Progress.character_available("maestra_luz") and Progress.select_character("profe_nico"), "Teacher purchases survive a new campaign")
	var personal_path: String = Progress.save_path
	Progress.save_path = "user://shop-teachers-test-only.json"
	Progress.session_only = false
	Progress.save_game()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.character == "profe_nico" and Progress.character_available("maestra_luz"), "Purchased teachers and selection survive a real save reload")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = personal_path
	Progress.session_only = true
	Progress.data = previous
	app.show_menu()
	await ticks()

func persistence() -> void:
	# A dedicated file exercises real JSON and the atomic save, never the personal profile.
	var original_path: String = Progress.save_path
	Progress.save_path = "user://incentives-test-only.json"
	Progress.session_only = false
	Progress.save_game()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.wallet == 15 and "heart" in Progress.data.purchases and Progress.data.relics.size() == 12, "Wallet, purchases and relics survive a real save reload")
	check(Progress.data.times["1"] == 230 and "collector" in Progress.data.achievements, "Records and achievements survive JSON serialization")
	check(not Progress.credit(120, "ex_1_1_credit_280"), "Reward ledger survives reload")
	# Simulate a version-1 save made before the shop existed.
	var old := {"version": 1, "credits": 42, "collected": ["1_credit_7"], "best": {"1": "B"}}
	var file := FileAccess.open(Progress.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.wallet == 42 and Progress.data.best["1"] == "B", "Legacy saves migrate their balance and grade")
	check(not Progress.credit(1, "1_credit_7"), "Legacy collected coins cannot be farmed")
	Progress.save_game()
	Progress.reset_data()
	Progress.load_game()
	check(Progress.data.wallet == 42, "Migration cannot duplicate the old balance")
	DirAccess.remove_absolute(Progress.save_path)
	Progress.save_path = original_path
	Progress.session_only = true
