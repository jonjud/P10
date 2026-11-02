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
	print("Craft: Passed ", passed, " / Failed ", failed)
