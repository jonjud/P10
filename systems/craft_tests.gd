extends RefCounted
class_name CraftTests

var db : ItemDatabase = ItemDatabase.new()
var passed : int = 0
var failed : int = 0

func t(label : String, cond : bool) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)

func ing(id : StringName, q : int) -> RecipeIngredient:
	var r := RecipeIngredient.new()
	r.item_id = id
	r.quantity = q
	return r

func out(id : StringName, q : int) -> RecipeOutput:
	var r := RecipeOutput.new()
	r.item_id = id
	r.quantity = q
	return r

func recipe(id : StringName, ins : Array, outs : Array, st : StringName = &"hand") -> CraftingRecipe:
	var r := CraftingRecipe.new()
	r.id = id
	r.station_required = st
	for i in ins:
		r.inputs.append(i)
	for o in outs:
		r.outputs.append(o)
	return r

func inv_with(items : Dictionary, slots : int = 20) -> Inventory:
	var inv := Inventory.new()
	inv.max_slots = slots
	for id in items:
		inv.add_to_existing_stacks(db, id, items[id])
	return inv

func run_all() -> void:
	db.load_from_directory("res://data/")
	var wb : CraftingRecipe = recipe(&"r_wb", [ing(&"wood_00", 6), ing(&"stone_00", 2)], [out(&"workbench_00", 1)])
	# สำเร็จ
	var a : Inventory = inv_with({&"wood_00": 10, &"stone_00": 5})
	var r : Dictionary = Crafter.craft(db, a, wb, [])
	t("hand ok", r["ok"] and r["done"] == 1 and r["requested"] == 1)
	t("hand consumed", a.count_of(&"wood_00") == 4 and a.count_of(&"stone_00") == 3)
	t("hand produced", a.count_of(&"workbench_00") == 1)
	# qty > 1
	a = inv_with({&"wood_00": 12, &"stone_00": 4})
	r = Crafter.craft(db, a, wb, [], 2)
	t("qty2 ok", r["ok"] and r["done"] == 2 and a.count_of(&"workbench_00") == 2 and a.count_of(&"wood_00") == 0)
	# วัตถุดิบไม่พอ: state ต้องไม่เปลี่ยน
	a = inv_with({&"wood_00": 5, &"stone_00": 5})
	var before : Dictionary = a.to_dict()
	r = Crafter.craft(db, a, wb, [])
	t("not enough", r["reason"] == CraftResult.NOT_ENOUGH and r["done"] == 0 and a.to_dict() == before)
	# สถานีผิด
	var ws : CraftingRecipe = recipe(&"r_ws", [ing(&"wood_00", 1)], [out(&"fiber_00", 1)], &"workbench")
	a = inv_with({&"wood_00": 5})
	before = a.to_dict()
	r = Crafter.craft(db, a, ws, [&"hand"])
	t("wrong station", r["reason"] == CraftResult.WRONG_STATION and a.to_dict() == before)
	r = Crafter.craft(db, a, ws, [&"workbench"])
	t("right station", r["ok"] and a.count_of(&"fiber_00") == 1)
	# output เต็ม: 1 ช่อง ใช้ wood ทั้งช่อง ได้ output ชนิดอื่นไม่มีที่
	var full : Inventory = inv_with({&"wood_00": 1}, 1)
	var one : CraftingRecipe = recipe(&"r_one", [ing(&"wood_00", 1)], [out(&"stone_00", 1)])
	r = Crafter.craft(db, full, one, [])
	t("slot freed by input -> ok", r["ok"] and full.count_of(&"stone_00") == 1)
	var full2 : Inventory = inv_with({&"wood_00": 99, &"stone_00": 1}, 2)
	var two : CraftingRecipe = recipe(&"r_two", [ing(&"stone_00", 1)], [out(&"fiber_00", 1)])
	var f2 : Dictionary = full2.to_dict()
	r = Crafter.craft(db, full2, two, [])
	t("input frees slot", r["ok"])
	var full3 : Inventory = inv_with({&"wood_00": 99, &"stone_00": 99}, 2)
	var three : CraftingRecipe = recipe(&"r_three", [ing(&"stone_00", 1)], [out(&"fiber_00", 200)])
	f2 = full3.to_dict()
	r = Crafter.craft(db, full3, three, [])
	t("output full atomic", r["reason"] == CraftResult.OUTPUT_FULL and r["done"] == 0 and full3.to_dict() == f2)
	# input ผิด
	var bad : CraftingRecipe = recipe(&"r_bad", [ing(&"no_such", 1)], [out(&"fiber_00", 1)])
	a = inv_with({&"wood_00": 5})
	before = a.to_dict()
	t("bad item", Crafter.craft(db, a, bad, [])["reason"] == CraftResult.BAD_RECIPE and a.to_dict() == before)
	t("qty 0", Crafter.craft(db, a, wb, [], 0)["reason"] == CraftResult.INVALID_QUANTITY)
	t("qty neg", Crafter.craft(db, a, wb, [], -1)["reason"] == CraftResult.INVALID_QUANTITY)
	t("null db", Crafter.craft(null, a, wb, [])["reason"] == CraftResult.NULL_DB)
	t("null inv", Crafter.craft(db, null, wb, [])["reason"] == CraftResult.NULL_INVENTORY)
	t("null recipe", Crafter.craft(db, a, null, [])["reason"] == CraftResult.UNKNOWN_RECIPE)
	t("empty recipe", Crafter.craft(db, a, CraftingRecipe.new(), [])["reason"] == CraftResult.BAD_RECIPE)
	# สัญญา: done เป็น 0 หรือ requested
	t("contract", r["done"] == 0 or r["done"] == r["requested"])
	test_station()
	test_atomic_craft()
	test_explain()
	test_recipe_db()
	test_real_recipes()
	test_old_tier_relevance()
	test_build_cost_chain()
	test_salvage_validator()
	test_salvager()
	test_no_free_loop()
	test_fuzz_exploit()
	test_failure_feedback()
	print("Craft: Passed ", passed, " / Failed ", failed)

func test_station() -> void:
	var g : BuildGrid = BuildGrid.new()
	var inv : Inventory = inv_with({&"workbench_00": 1, &"wall_00": 1})
	g.place(db, inv, &"workbench_00", Vector2i(5, 5), 0)
	g.place(db, inv, &"wall_00", Vector2i(2, 2), 0)
	var wb_pos : Vector2 = BuildConst.cell_to_world(Vector2i(5, 5))
	t("hand always", StationFinder.available(db, g, Vector2(0, 0)) == [&"hand"])
	t("near wb", StationFinder.available(db, g, wb_pos + Vector2(10, 10)).has(&"workbench_00"))
	t("near edge", StationFinder.available(db, g, wb_pos + Vector2(64 + 60, 16)).has(&"workbench_00"))
	t("far wb", not StationFinder.available(db, g, wb_pos + Vector2(64 + 70, 16)).has(&"workbench_00"))
	t("wall not station", not StationFinder.available(db, g, BuildConst.cell_to_world(Vector2i(2, 2))).has(&"wall_00"))
	t("null grid", StationFinder.available(db, null, Vector2.ZERO) == [&"hand"])
	t("no dup", StationFinder.available(db, g, wb_pos).count(&"workbench_00") == 1)

func test_atomic_craft() -> void:
	var wb : CraftingRecipe = recipe(&"r_wb", [ing(&"wood_00", 6), ing(&"stone_00", 2)], [out(&"workbench_00", 1)])
	# คำขอเดียว = craft ครั้งเดียว แม้วัตถุดิบพอทำสามครั้ง
	var a : Inventory = inv_with({&"wood_00": 18, &"stone_00": 6})
	var r : Dictionary = Crafter.craft(db, a, wb, [])
	t("single request once", r["done"] == 1 and a.count_of(&"workbench_00") == 1 and a.count_of(&"wood_00") == 12)
	# ล้มทุกแบบ inventory ต้องไม่เปลี่ยน
	var ws : CraftingRecipe = recipe(&"r_ws", [ing(&"wood_00", 1)], [out(&"fiber_00", 1)], &"workbench_00")
	var bad : CraftingRecipe = recipe(&"r_bad", [ing(&"no_such", 1)], [out(&"fiber_00", 1)])
	var big : CraftingRecipe = recipe(&"r_big", [ing(&"stone_00", 1)], [out(&"fiber_00", 500)])
	var cases : Array = [
		["not_enough", wb, [], 99],
		["wrong_station", ws, [&"hand"], 1],
		["bad_recipe", bad, [], 1],
		["output_full", big, [], 1],
		["qty0", wb, [], 0],
	]
	for c in cases:
		var inv : Inventory = inv_with({&"wood_00": 5, &"stone_00": 5}, 2)
		var snap : Dictionary = inv.to_dict()
		var res : Dictionary = Crafter.craft(db, inv, c[1], c[2], c[3])
		t("fail unchanged " + c[0], not res["ok"] and res["done"] == 0 and inv.to_dict() == snap)
	# success แล้ว inventory เปลี่ยนตรงตามสูตรเท่านั้น (ผลรวม input ลด, output เพิ่ม)
	var s : Inventory = inv_with({&"wood_00": 6, &"stone_00": 2})
	Crafter.craft(db, s, wb, [])
	t("success exact", s.count_of(&"wood_00") == 0 and s.count_of(&"stone_00") == 0 and s.count_of(&"workbench_00") == 1)

func test_explain() -> void:
	var wb : CraftingRecipe = recipe(&"r_wb", [ing(&"wood_00", 6), ing(&"stone_00", 2)], [out(&"workbench_00", 1)])
	var a : Inventory = inv_with({&"wood_00": 4, &"stone_00": 2})
	var before : Dictionary = a.to_dict()
	var e : Dictionary = Crafter.explain(db, a, wb, [])
	t("explain not enough", e["reason"] == CraftResult.NOT_ENOUGH and e["missing"] == {&"wood_00": 2})
	t("explain no mutate", a.to_dict() == before)
	var ws : CraftingRecipe = recipe(&"r_ws", [ing(&"wood_00", 1)], [out(&"fiber_00", 1)], &"workbench_00")
	e = Crafter.explain(db, a, ws, [&"hand"])
	t("explain wrong station", e["reason"] == CraftResult.WRONG_STATION and e["station"] == &"workbench_00")
	e = Crafter.explain(db, a, ws, [&"workbench_00"])
	t("explain ok", e["ok"] and e["missing"].is_empty())
	var both : CraftingRecipe = recipe(&"r_both", [ing(&"wood_00", 99)], [out(&"fiber_00", 1)], &"workbench_00")
	e = Crafter.explain(db, a, both, [])
	t("explain station and missing", e["reason"] == CraftResult.WRONG_STATION and e["missing"].has(&"wood_00"))
	t("explain qty scales", Crafter.explain(db, a, wb, [], 2)["missing"] == {&"wood_00": 8, &"stone_00": 2})
	t("msg all reasons", CraftMessages.of(CraftResult.NOT_ENOUGH) != "" and CraftMessages.of(CraftResult.WRONG_STATION) != "")
	t("msg unknown fallback", CraftMessages.of(&"zzz").contains("zzz"))

func test_recipe_db() -> void:
	var good : CraftingRecipe = recipe(&"r_ok", [ing(&"wood_00", 2)], [out(&"fiber_00", 1)])
	t("validate ok", RecipeDatabase.validate_recipe(good, db).is_empty())
	var bad_in : CraftingRecipe = recipe(&"r_x", [ing(&"no_such", 1)], [out(&"fiber_00", 1)])
	t("validate bad input item", RecipeDatabase.validate_recipe(bad_in, db).size() == 1)
	var bad_out : CraftingRecipe = recipe(&"r_y", [ing(&"wood_00", 1)], [out(&"no_such", 1)])
	t("validate bad output item", RecipeDatabase.validate_recipe(bad_out, db).size() == 1)
	var zero : CraftingRecipe = recipe(&"r_z", [ing(&"wood_00", 0)], [out(&"fiber_00", 1)])
	t("validate zero qty", RecipeDatabase.validate_recipe(zero, db).size() == 1)
	t("validate empty", RecipeDatabase.validate_recipe(CraftingRecipe.new(), db).size() >= 3)
	t("validate null", RecipeDatabase.validate_recipe(null, db).size() == 1)
	var rdb : RecipeDatabase = RecipeDatabase.new()
	t("load null item_db", not rdb.load_from_directory("res://data/recipes/", null))
	t("load bad dir", not rdb.load_from_directory("res://no_such_dir/", db))
	t("failed load keeps empty", rdb.all_ids().is_empty())
	var bad_st : CraftingRecipe = recipe(&"r_s", [ing(&"wood_00", 1)], [out(&"fiber_00", 1)], &"workbench")
	t("validate bad station", RecipeDatabase.validate_recipe(bad_st, db).size() == 1)
	var good_st : CraftingRecipe = recipe(&"r_s2", [ing(&"wood_00", 1)], [out(&"fiber_00", 1)], &"workbench_00")
	t("validate good station", RecipeDatabase.validate_recipe(good_st, db).is_empty())

func test_real_recipes() -> void:
	var rdb : RecipeDatabase = RecipeDatabase.new()
	var ok : bool = rdb.load_from_directory("res://data/recipes/", db)
	if not ok:
		print("RecipeDatabase errors: ", rdb.errors)
	t("recipes load", ok)
	t("9 recipes", rdb.all_ids().size() == 9)
	t("new items exist", db.has_item(&"plank_00") and db.has_item(&"wood_handle_00") and db.has_item(&"ore_00") and db.has_item(&"ingot_00") and db.has_item(&"iron_axe_00"))
	if not ok:
		return
	# recursive: wood -> plank -> handle -> ... -> iron_axe ด้วยสูตรจริงทั้งสาย
	var inv : Inventory = inv_with({&"wood_00": 6, &"stone_00": 2, &"fiber_00": 3, &"ore_00": 4})
	var st : Array = [&"hand"]
	t("c1 workbench", Crafter.craft(db, inv, rdb.get_recipe(&"r_workbench"), st)["ok"])
	st = [&"hand", &"workbench_00"]
	t("c2 plank blocked: no wood", Crafter.craft(db, inv, rdb.get_recipe(&"r_plank"), st)["reason"] == CraftResult.NOT_ENOUGH)
	inv.add_to_existing_stacks(db, &"wood_00", 4)
	t("c3 plank", Crafter.craft(db, inv, rdb.get_recipe(&"r_plank"), st, 2)["ok"] and inv.count_of(&"plank_00") == 4)
	t("c4 handle", Crafter.craft(db, inv, rdb.get_recipe(&"r_handle"), st)["ok"] and inv.count_of(&"wood_handle_00") == 1)
	t("c5 ingot", Crafter.craft(db, inv, rdb.get_recipe(&"r_ingot"), st, 2)["ok"] and inv.count_of(&"ingot_00") == 2)
	t("c6 iron axe uses handle", Crafter.craft(db, inv, rdb.get_recipe(&"r_iron_axe"), st)["ok"])
	t("c7 axe made, handle+ingot consumed", inv.count_of(&"iron_axe_00") == 1 and inv.count_of(&"wood_handle_00") == 0 and inv.count_of(&"ingot_00") == 0)
	t("c8 axe needs station", Crafter.craft(db, inv_with({&"ingot_00": 2, &"wood_handle_00": 1}), rdb.get_recipe(&"r_iron_axe"), [&"hand"])["reason"] == CraftResult.WRONG_STATION)

func test_old_tier_relevance() -> void:
	var rdb : RecipeDatabase = RecipeDatabase.new()
	if not rdb.load_from_directory("res://data/recipes/", db):
		t("old tier: recipes load", false)
		return
	# นับว่า item แต่ละชนิดเป็น input ของกี่สูตร
	var used : Dictionary = {}
	var tier2_has_tier1_input : bool = false
	for rid in rdb.all_ids():
		var r : CraftingRecipe = rdb.get_recipe(rid)
		for i in r.inputs:
			used[i.item_id] = used.get(i.item_id, 0) + 1
			if r.tier == 2 and db.get_item(i.item_id).tags.has(&"tier1"):
				tier2_has_tier1_input = true
	t("tier2 recipe uses tier1 input", tier2_has_tier1_input)
	t("plank used in >=4 recipes", used.get(&"plank_00", 0) >= 4)
	t("handle used in >=2 recipes", used.get(&"wood_handle_00", 0) >= 2)
	t("fiber used >=1", used.get(&"fiber_00", 0) >= 1)
	# ไม่มี item tier0/tier1 ที่เป็นทางตัน (ไม่ใช่ input ของสูตรไหนเลย) ยกเว้น Finished
	for id in [&"wood_00", &"stone_00", &"fiber_00", &"plank_00", &"wood_handle_00"]:
		t("not dead end " + String(id), used.get(id, 0) >= 1)

func test_build_cost_chain() -> void:
	var rdb : RecipeDatabase = RecipeDatabase.new()
	if not rdb.load_from_directory("res://data/recipes/", db):
		t("build chain: recipes load", false)
		return
	var inv : Inventory = inv_with({&"wood_00": 20, &"stone_00": 6})
	var g : BuildGrid = BuildGrid.new()
	var st : Array = [&"hand"]
	# workbench: hand craft แล้ววางลง grid
	t("bc workbench craft", Crafter.craft(db, inv, rdb.get_recipe(&"r_workbench"), st)["ok"])
	t("bc workbench place", g.place(db, inv, &"workbench_00", Vector2i(5, 5), 0)["ok"])
	# สถานีใกล้ผู้เล่น -> craft ชิ้นส่วนอื่นได้
	var near : Vector2 = BuildConst.cell_to_world(Vector2i(5, 5)) + Vector2(10, 10)
	st = StationFinder.available(db, g, near)
	t("bc station found", st.has(&"workbench_00"))
	t("bc plank", Crafter.craft(db, inv, rdb.get_recipe(&"r_plank"), st, 5)["ok"] and inv.count_of(&"plank_00") == 10)
	t("bc wall", Crafter.craft(db, inv, rdb.get_recipe(&"r_wall"), st)["ok"])
	t("bc floor", Crafter.craft(db, inv, rdb.get_recipe(&"r_floor"), st)["ok"])
	t("bc chest", Crafter.craft(db, inv, rdb.get_recipe(&"r_chest"), st)["ok"])
	t("bc place wall", g.place(db, inv, &"wall_00", Vector2i(2, 2), 0)["ok"])
	t("bc place floor", g.place(db, inv, &"floor_00", Vector2i(2, 2), 0)["ok"])
	t("bc place chest", g.place(db, inv, &"chest_00", Vector2i(8, 8), 0)["ok"])
	# ตัวเลข: wood 20-6=14 -> plank x5 ใช้ wood 10 เหลือ 4; plank 10 -2-1-4 = 3; stone 6-2-2 = 2
	t("bc leftovers", inv.count_of(&"wood_00") == 4 and inv.count_of(&"plank_00") == 3 and inv.count_of(&"stone_00") == 2)
	# ไกลสถานี -> craft ไม่ได้
	var far : Array = StationFinder.available(db, g, Vector2(600, 400))
	t("bc far blocked", Crafter.craft(db, inv, rdb.get_recipe(&"r_wall"), far)["reason"] == CraftResult.WRONG_STATION)
	# รื้อ workbench คืนเข้ากระเป๋า (P-04 ไม่เปลี่ยน) แล้วสถานีหาย
	t("bc remove wb", g.remove_at(db, inv, Vector2i(5, 5))["ok"] and not StationFinder.available(db, g, near).has(&"workbench_00"))

func test_salvage_validator() -> void:
	var rdb : RecipeDatabase = RecipeDatabase.new()
	if not rdb.load_from_directory("res://data/recipes/", db):
		t("salvage: recipes load", false)
		return
	var errs : Array = SalvageValidator.validate(db, rdb)
	if not errs.is_empty():
		print("Salvage errors: ", errs)
	t("real data valid", errs.is_empty())
	t("default false", ItemData.new().can_be_salvaged == false)
	t("sword salvageable", db.get_item(&"wooden_sword_00").can_be_salvaged)
	t("wood not salvageable", not db.get_item(&"wood_00").can_be_salvaged)
	# เคสผิดบนสำเนา: ตั้งค่าแล้วคืนค่าเดิม
	var sw : ItemData = db.get_item(&"wooden_sword_00")
	var saved : Array[SalvageEntry] = sw.salvage_yield.duplicate()
	sw.salvage_yield.clear()
	t("no core caught", not SalvageValidator.validate(db, rdb).is_empty())
	var greedy : SalvageEntry = SalvageEntry.new()
	greedy.item_id = &"plank_00"
	greedy.min_quantity = 4
	greedy.max_quantity = 4
	sw.salvage_yield.append(greedy)
	t("value >= cost caught", not SalvageValidator.validate(db, rdb).is_empty())
	sw.salvage_yield.clear()
	var badcore : SalvageEntry = SalvageEntry.new()
	badcore.item_id = &"plank_00"
	badcore.min_quantity = 1
	badcore.max_quantity = 2
	sw.salvage_yield.append(badcore)
	t("core min!=max caught", not SalvageValidator.validate(db, rdb).is_empty())
	sw.salvage_yield.clear()
	for e in saved:
		sw.salvage_yield.append(e)
	var sw2 : ItemData = db.get_item(&"wooden_sword_00")
	var keep : Array[SalvageEntry] = sw2.salvage_yield.duplicate()
	var bn : SalvageEntry = SalvageEntry.new()
	bn.item_id = &"fiber_00"
	bn.min_quantity = 1
	bn.max_quantity = 1
	bn.is_bonus = true
	bn.chance = 0.5
	sw2.salvage_yield.append(bn)
	t("small bonus ok", SalvageValidator.validate(db, rdb).is_empty())
	bn.max_quantity = 3
	t("bonus qty>1 caught", not SalvageValidator.validate(db, rdb).is_empty())
	bn.max_quantity = 1
	bn.item_id = &"plank_00"
	t("bonus value >50% caught", not SalvageValidator.validate(db, rdb).is_empty())
	sw2.salvage_yield.clear()
	for e in keep:
		sw2.salvage_yield.append(e)
	var sw3 : ItemData = db.get_item(&"wooden_sword_00")
	var keep3 : Array[SalvageEntry] = sw3.salvage_yield.duplicate()
	sw3.salvage_yield.clear()
	var rawcore : SalvageEntry = SalvageEntry.new()
	rawcore.item_id = &"wood_00"
	rawcore.min_quantity = 1
	rawcore.max_quantity = 1
	sw3.salvage_yield.append(rawcore)
	t("all-raw core caught", not SalvageValidator.validate(db, rdb).is_empty())
	sw3.salvage_yield.clear()
	for e in keep3:
		sw3.salvage_yield.append(e)
	t("restored valid", SalvageValidator.validate(db, rdb).is_empty())

func test_salvager() -> void:
	var st : Array = [&"hand", &"workbench_00"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# sword -> plank x1 (core ไม่สุ่ม)
	var a : Inventory = inv_with({&"wooden_sword_00": 1})
	var r : Dictionary = Salvager.salvage(db, a, &"wooden_sword_00", st, 1, rng)
	t("sv sword ok", r["ok"] and a.count_of(&"wooden_sword_00") == 0 and a.count_of(&"plank_00") == 1)
	# iron_axe -> ingot + handle (ระดับกลาง ไม่กลับเป็น ore/wood)
	a = inv_with({&"iron_axe_00": 1})
	Salvager.salvage(db, a, &"iron_axe_00", st, 1, rng)
	t("sv axe intermediate", a.count_of(&"ingot_00") == 1 and a.count_of(&"wood_handle_00") == 1 and a.count_of(&"ore_00") == 0 and a.count_of(&"wood_00") == 0)
	# ห้ามได้ 0: chest ทุก seed ได้ plank >= 2
	var zero_hit : bool = false
	var bonus_seen : bool = false
	for s in 60:
		rng.seed = s
		a = inv_with({&"chest_00": 1})
		Salvager.salvage(db, a, &"chest_00", st, 1, rng)
		if a.count_of(&"plank_00") < 2:
			zero_hit = true
		if a.count_of(&"stone_00") > 0:
			bonus_seen = true
	t("sv core never zero", not zero_hit)
	t("sv bonus sometimes", bonus_seen)
	# seed เดียวกัน = ผลเดียวกัน
	rng.seed = 99
	var b1 : Inventory = inv_with({&"chest_00": 5})
	Salvager.salvage(db, b1, &"chest_00", st, 5, rng)
	rng.seed = 99
	var b2 : Inventory = inv_with({&"chest_00": 5})
	Salvager.salvage(db, b2, &"chest_00", st, 5, rng)
	t("sv deterministic", b1.to_dict() == b2.to_dict())
	for id in [&"wooden_sword_00", &"iron_axe_00", &"wall_00", &"chest_00"]:
		t("sv station set " + String(id), db.get_item(id).salvage_station == &"workbench_00")
	# ล้มแล้ว state ไม่เปลี่ยน
	var cases : Array = [
		["not salvageable", &"wood_00", st, CraftResult.NOT_SALVAGEABLE],
		["wrong station", &"wall_00", [&"hand"], CraftResult.WRONG_STATION],
		["not enough", &"wall_00", st, CraftResult.NOT_ENOUGH],
	]
	for c in cases:
		var inv : Inventory = inv_with({&"wood_00": 5, &"wall_00": 1})
		var snap : Dictionary = inv.to_dict()
		var res : Dictionary = Salvager.salvage(db, inv, c[1], c[2], 2 if c[0] == "not enough" else 1, rng)
		t("sv fail " + c[0], not res["ok"] and res["done"] == 0 and inv.to_dict() == snap and res["reason"] == c[3])
	# output เต็ม: 1 ช่อง มี chest ช่องเดียว (ว่างหลังหัก) แต่ yield ต้องการ 2 ช่อง (plank+stone) หรือ plank เกิน
	var tight : Inventory = inv_with({&"iron_axe_00": 1}, 1)
	var snap2 : Dictionary = tight.to_dict()
	r = Salvager.salvage(db, tight, &"iron_axe_00", st, 1, rng)
	t("sv output full atomic", r["reason"] == CraftResult.OUTPUT_FULL and tight.to_dict() == snap2)
	# lossy: มูลค่าที่ได้ < ต้นทุนในทุก seed
	for s in 30:
		rng.seed = s
		a = inv_with({&"chest_00": 1})
		Salvager.salvage(db, a, &"chest_00", st, 1, rng)
		var v : int = a.count_of(&"plank_00") * 3 + a.count_of(&"stone_00") * 2
		if v >= 16:
			t("sv lossy chest seed %d" % s, false)
	t("sv contract", r["done"] == 0 or r["done"] == r["requested"])

func test_no_free_loop() -> void:
	var rdb : RecipeDatabase = RecipeDatabase.new()
	if not rdb.load_from_directory("res://data/recipes/", db):
		t("loop: recipes load", false)
		return
	var st : Array = [&"hand", &"workbench_00"]
	var rng := RandomNumberGenerator.new()
	# ใช้ค่า bonus สูงสุด (chance 1.0) เพื่อกรณีเลวร้ายที่สุด ผ่าน max_value ใน validator แล้ว
	# ที่นี่ทดสอบจริงด้วย seed หลายค่า
	var cycles : Array = [
		[&"r_wall", &"wall_00"],
		[&"r_chest", &"chest_00"],
		[&"r_sword", &"wooden_sword_00"],
		[&"r_iron_axe", &"iron_axe_00"],
	]
	for c in cycles:
		for s in 20:
			rng.seed = s
			var inv : Inventory = inv_with({&"plank_00": 40, &"wood_handle_00": 10, &"stone_00": 10, &"ingot_00": 20}, 20)
			var v0 : int = _inv_value(inv)
			for n in 8:
				if not Crafter.craft(db, inv, rdb.get_recipe(c[0]), st)["ok"]:
					break
				if not Salvager.salvage(db, inv, c[1], st, 1, rng)["ok"]:
					break
			if _inv_value(inv) > v0:
				t("loop gain %s seed %d" % [c[1], s], false)
	t("no free loop ran", true)

func _inv_value(inv : Inventory) -> int:
	var v : int = 0
	for sl in inv.slots:
		if sl != null and sl.item_data != null:
			v += sl.item_data.value * sl.quantity
	return v

func test_fuzz_exploit() -> void:
	var rdb : RecipeDatabase = RecipeDatabase.new()
	if not rdb.load_from_directory("res://data/recipes/", db):
		t("fuzz: recipes load", false)
		return
	var rng := RandomNumberGenerator.new()
	var raws : Array = [&"wood_00", &"stone_00", &"fiber_00", &"ore_00"]
	var salv : Array = [&"wooden_sword_00", &"iron_axe_00", &"wall_00", &"chest_00"]
	var rids : Array = rdb.all_ids()
	var bad_gain : int = 0
	var bad_unchanged : int = 0
	var bad_internal : int = 0
	var crafts : int = 0
	var salvs : int = 0
	for seed_i in 20:
		rng.seed = 1000 + seed_i
		var inv : Inventory = inv_with({}, 20)
		var gathered : int = 0
		var st : Array = [&"hand", &"workbench_00"]
		for step in 300:
			var k : int = rng.randi() % 10
			var before : Dictionary = inv.to_dict()
			var r : Dictionary = {}
			if k <= 2:
				var id : StringName = raws[rng.randi() % raws.size()]
				r = inv.add_to_existing_stacks(db, id, rng.randi_range(1, 12))
				gathered += db.get_item(id).value * r["done"]
			elif k <= 6:
				r = Crafter.craft(db, inv, rdb.get_recipe(rids[rng.randi() % rids.size()]), st, rng.randi_range(1, 3))
				if r["done"] > 0:
					crafts += 1
			elif k <= 8:
				r = Salvager.salvage(db, inv, salv[rng.randi() % salv.size()], st, rng.randi_range(1, 2), rng)
				if r["done"] > 0:
					salvs += 1
			else:
				var rid2 : StringName = raws[rng.randi() % raws.size()]
				r = inv.remove_item(db, rid2, rng.randi_range(1, 5))
			if r.get("reason", &"") == CraftResult.INTERNAL:
				bad_internal += 1
			if r["done"] == 0 and inv.to_dict() != before:
				bad_unchanged += 1
			var rv : float = _raw_value(inv, rdb)
			if rv > float(gathered) + 0.001:
				bad_gain += 1
				if bad_gain == 1:
					print("fuzz gain: seed=", seed_i, " step=", step, " k=", k, " raw=", rv, " gathered=", gathered)
	t("fuzz: raw value never exceeds gathered", bad_gain == 0)
	t("fuzz: failed op leaves state unchanged", bad_unchanged == 0)
	t("fuzz: no INTERNAL", bad_internal == 0)
	t("fuzz: exercised crafts and salvages", crafts > 50 and salvs > 20)
	print("fuzz: crafts=", crafts, " salvages=", salvs)

func test_failure_feedback() -> void:
	# ทุก reason ที่ craft/salvage คืนได้ ต้องมีข้อความ ไม่ตกไป fallback
	for rs in [CraftResult.NOT_ENOUGH, CraftResult.WRONG_STATION, CraftResult.OUTPUT_FULL, CraftResult.BAD_RECIPE, CraftResult.UNKNOWN_RECIPE, CraftResult.INVALID_QUANTITY, CraftResult.NOT_SALVAGEABLE, CraftResult.NO_SALVAGE_DATA]:
		t("msg has text " + String(rs), CraftMessages.TEXT.has(rs) and CraftMessages.TEXT[rs] != "")
	# สถานีหายหลังวางแล้ว: craft ได้ก่อนรื้อ ไม่ได้หลังรื้อ และของไม่หาย
	var rdb : RecipeDatabase = RecipeDatabase.new()
	if not rdb.load_from_directory("res://data/recipes/", db):
		t("fb: recipes load", false)
		return
	var g : BuildGrid = BuildGrid.new()
	var inv : Inventory = inv_with({&"workbench_00": 1, &"wood_00": 10})
	g.place(db, inv, &"workbench_00", Vector2i(5, 5), 0)
	var near : Vector2 = BuildConst.cell_to_world(Vector2i(5, 5)) + Vector2(10, 10)
	t("fb craft with station", Crafter.craft(db, inv, rdb.get_recipe(&"r_plank"), StationFinder.available(db, g, near))["ok"])
	g.remove_at(db, inv, Vector2i(5, 5))
	var snap : Dictionary = inv.to_dict()
	var r : Dictionary = Crafter.craft(db, inv, rdb.get_recipe(&"r_plank"), StationFinder.available(db, g, near))
	t("fb craft after removal blocked", r["reason"] == CraftResult.WRONG_STATION and inv.to_dict() == snap)
	t("fb message for it", CraftMessages.of(r["reason"]) != "")

# ต้นทุน raw ของ item 1 ชิ้น
# ไม่มีสูตรผลิต = raw ใช้ value ของมันเอง
# มีสูตร = ต้นทุน input ของสูตรที่ถูกที่สุด หารจำนวน output
func _raw_cost(id : StringName, rdb : RecipeDatabase, memo : Dictionary) -> float:
	if memo.has(id):
		return memo[id]
	memo[id] = float(db.get_item(id).value)   # กันวนไม่รู้จบถ้าสูตรวงกลม
	var best : float = -1.0
	for rid in rdb.all_ids():
		var r : CraftingRecipe = rdb.get_recipe(rid)
		var produced : int = 0
		for o in r.outputs:
			if o.item_id == id:
				produced += o.quantity
		if produced <= 0:
			continue
		var c : float = 0.0
		for i in r.inputs:
			c += _raw_cost(i.item_id, rdb, memo) * i.quantity
		c /= produced
		if best < 0.0 or c < best:
			best = c
	if best >= 0.0:
		memo[id] = best
	return memo[id]

func _raw_value(inv : Inventory, rdb : RecipeDatabase) -> float:
	var memo : Dictionary = {}
	var v : float = 0.0
	for sl in inv.slots:
		if sl != null and sl.item_data != null and sl.quantity > 0:
			v += _raw_cost(sl.item_data.id, rdb, memo) * sl.quantity
	return v
