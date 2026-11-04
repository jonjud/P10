extends Node2D
# P10-17 (ก): เล่นวงจร gather -> craft -> build -> salvage -> reuse
# UI ไม่ถือ state: อยู่ใน Inventory / BuildGrid ทั้งหมด

const REASONS : Dictionary = {
	BuildGrid.OK: "วางแล้ว",
	BuildGrid.OUT_OF_BOUNDS: "ออกนอกพื้นที่",
	BuildGrid.OVERLAP: "มีของวางทับอยู่",
	BuildGrid.CANNOT_ROTATE: "ชิ้นนี้หมุนไม่ได้",
	BuildGrid.NOT_ENOUGH: "ไม่มีชิ้นนี้ในกระเป๋า",
	BuildGrid.NO_STRUCTURE: "ไม่มีอะไรให้รื้อ",
	BuildGrid.CHEST_NOT_EMPTY: "หีบยังมีของ เอาออกก่อน",
	BuildGrid.INVENTORY_FULL: "กระเป๋าเต็ม รื้อไม่ได้",
}
const PICK_MSG : Dictionary = {
	OpResult.OK: "เก็บแล้ว",
	OpResult.PARTIAL_FULL: "เก็บได้ไม่ครบ กระเป๋าเต็ม",
	OpResult.FULL: "กระเป๋าเต็ม",
}
const CAT_COLORS : Array = [Color(0.55, 0.45, 0.3), Color(0.5, 0.5, 0.55), Color(0.3, 0.5, 0.8), Color(0.8, 0.6, 0.2)]
const CAT_NAMES : Array = ["พื้น", "ผนัง", "สถานี", "หีบ"]

var db : ItemDatabase = ItemDatabase.new()
var rdb : RecipeDatabase = RecipeDatabase.new()
var inv : Inventory = Inventory.new()
var grid : BuildGrid = BuildGrid.new()
var player : CharacterBody2D
var build_mode : bool = false
var cat : int = 0
var sel_id : StringName = &""
var rot : int = 0
var _cell : Vector2i = Vector2i.ZERO
var _ghost : Dictionary = {}
var _target : Dictionary = {}
var _stations : Array = [&"hand"]
var status : Label
var hint : Label
var msg : Label
var inv_lbl : Label
var prompt : Label
var cat_bar : HBoxContainer
var piece_grid : GridContainer
var recipe_box : VBoxContainer
var salvage_box : VBoxContainer

func _ready() -> void:
	_ensure_actions()
	if not db.load_from_directory("res://data/"):
		push_error("P10Play: โหลด item ไม่ได้")
	if not rdb.load_from_directory("res://data/recipes/", db):
		push_error("P10Play: โหลดสูตรไม่ได้ %s" % str(rdb.errors))
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(320, 400)
	add_child(player)
	player.inv = inv   # ตั้งหลัง add_child เพราะ _ready ของ player สร้างของตัวเองไว้ก่อน
	player.db = db
	player.pickup_done.connect(_on_pickup_done)
	# Ore วางไกลบ้าน (ตัวแทน Rocky Hills)
	for p in [[&"wood_00", 40, Vector2(160, 400)], [&"stone_00", 10, Vector2(480, 400)], [&"fiber_00", 6, Vector2(320, 250)], [&"ore_00", 8, Vector2(600, 60)]]:
		var pk : Pickup = (load("res://scenes/pickup.tscn") as PackedScene).instantiate()
		pk.item_id = p[0]
		pk.amount = p[1]
		pk.position = p[2]
		pk.add_to_group("pickup")
		add_child(pk)
	inv.inventory_changed.connect(_refresh_all)
	_build_ui()
	_set_mode(false)

func _ensure_actions() -> void:
	var keys : Dictionary = {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev : InputEventKey = InputEventKey.new()
			ev.physical_keycode = keys[a]
			InputMap.action_add_event(a, ev)

func _build_ui() -> void:
	var layer : CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var left : VBoxContainer = VBoxContainer.new()
	left.position = Vector2(680, 10)
	layer.add_child(left)
	status = Label.new()
	left.add_child(status)
	cat_bar = HBoxContainer.new()
	left.add_child(cat_bar)
	for i in CAT_NAMES.size():
		var b : Button = Button.new()
		b.text = CAT_NAMES[i]
		b.pressed.connect(_set_cat.bind(i))
		cat_bar.add_child(b)
	piece_grid = GridContainer.new()
	piece_grid.columns = 2
	left.add_child(piece_grid)
	hint = Label.new()
	left.add_child(hint)
	msg = Label.new()
	left.add_child(msg)
	inv_lbl = Label.new()
	left.add_child(inv_lbl)
	var right : VBoxContainer = VBoxContainer.new()
	right.position = Vector2(900, 10)
	layer.add_child(right)
	var t1 : Label = Label.new()
	t1.text = "สูตร (กดเพื่อ craft)"
	right.add_child(t1)
	recipe_box = VBoxContainer.new()
	right.add_child(recipe_box)
	var t2 : Label = Label.new()
	t2.text = "Salvage (กดเพื่อ salvage 1 ชิ้น)"
	right.add_child(t2)
	salvage_box = VBoxContainer.new()
	right.add_child(salvage_box)
	prompt = Label.new()
	prompt.position = Vector2(10, 500)
	layer.add_child(prompt)

func _set_mode(v : bool) -> void:
	build_mode = v
	cat_bar.visible = v
	piece_grid.visible = v
	hint.visible = v
	status.text = "BUILD | ซ้าย=วาง ขวา=รื้อ R=หมุน B=ออก" if v else "WASD เดิน | E เก็บของ | B สร้าง | ยืนใกล้ Workbench เพื่อ craft"
	_refresh_all()
	queue_redraw()

func _set_cat(i : int) -> void:
	cat = i
	sel_id = &""
	rot = 0
	_refresh_pieces()

func _select(id : StringName) -> void:
	sel_id = id
	rot = 0
	_refresh_pieces()

func _name(id : StringName) -> String:
	var it : ItemData = db.get_item(id)
	return it.display_name if it != null else String(id)

func _refresh_all() -> void:
	_refresh_pieces()
	_refresh_craft()
	_refresh_salvage()
	var parts : PackedStringArray = []
	var seen : Dictionary = {}
	for s in inv.slots:
		if s != null and s.item_data != null and s.quantity > 0 and not seen.has(s.item_data.id):
			seen[s.item_data.id] = true
			parts.append("%s x%d" % [s.item_data.display_name, inv.count_of(s.item_data.id)])
	inv_lbl.text = "กระเป๋า: " + (", ".join(parts) if not parts.is_empty() else "ว่าง")

func _refresh_pieces() -> void:
	for c in piece_grid.get_children():
		piece_grid.remove_child(c)
		c.queue_free()
	var seen : Dictionary = {}
	for s in inv.slots:
		if s == null or s.item_data == null or s.quantity <= 0 or not (s.item_data is BuildingPieceData):
			continue
		var p : BuildingPieceData = s.item_data
		if p.category != cat or seen.has(p.id):
			continue
		seen[p.id] = true
		var b : Button = Button.new()
		b.text = "%s%s x%d" % ["> " if p.id == sel_id else "", p.display_name, inv.count_of(p.id)]
		b.pressed.connect(_select.bind(p.id))
		piece_grid.add_child(b)

func _refresh_craft() -> void:
	for c in recipe_box.get_children():
		recipe_box.remove_child(c)
		c.queue_free()
	for rid in rdb.all_ids():
		var r : CraftingRecipe = rdb.get_recipe(rid)
		var e : Dictionary = Crafter.explain(db, inv, r, _stations)
		var txt : String = r.display_name
		if e["ok"]:
			txt = "[พร้อม] " + txt
		else:
			var why : PackedStringArray = []
			if e["reason"] == CraftResult.WRONG_STATION:
				why.append("ต้องใกล้ " + _name(e["station"]))
			for id in e["missing"]:
				why.append("ขาด %s x%d" % [_name(id), e["missing"][id]])
			txt = "%s (%s)" % [txt, ", ".join(why) if not why.is_empty() else CraftMessages.of(e["reason"])]
		var b : Button = Button.new()
		b.text = txt
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_craft.bind(rid))
		recipe_box.add_child(b)

func _refresh_salvage() -> void:
	for c in salvage_box.get_children():
		salvage_box.remove_child(c)
		c.queue_free()
	var seen : Dictionary = {}
	for s in inv.slots:
		if s == null or s.item_data == null or s.quantity <= 0 or not s.item_data.can_be_salvaged or seen.has(s.item_data.id):
			continue
		seen[s.item_data.id] = true
		var b : Button = Button.new()
		b.text = "Salvage %s (มี %d)" % [s.item_data.display_name, inv.count_of(s.item_data.id)]
		b.pressed.connect(_salvage.bind(s.item_data.id))
		salvage_box.add_child(b)

func _craft(rid : StringName) -> void:
	var r : Dictionary = Crafter.craft(db, inv, rdb.get_recipe(rid), _stations)
	msg.text = "คราฟต์สำเร็จ" if r["ok"] else CraftMessages.of(r["reason"])

func _salvage(id : StringName) -> void:
	var r : Dictionary = Salvager.salvage(db, inv, id, _stations)
	msg.text = "salvage สำเร็จ" if r["ok"] else CraftMessages.of(r["reason"])

func _show(reason : StringName) -> void:
	msg.text = REASONS.get(reason, String(reason))

func _rotate() -> void:
	var p : BuildingPieceData = db.get_item(sel_id) as BuildingPieceData
	if p == null:
		return
	if p.can_be_rotated:
		rot = (rot + 1) % 4
	else:
		_show(BuildGrid.CANNOT_ROTATE)

func _place() -> void:
	if sel_id == &"":
		msg.text = "เลือกชิ้นส่วนก่อน"
		return
	var r : Dictionary = grid.place(db, inv, sel_id, _cell, rot)
	_show(r["reason"])
	if r["done"] > 0 and inv.count_of(sel_id) < 1:
		sel_id = &""
	_refresh_all()

func _remove() -> void:
	_show(grid.remove_at(db, inv, _cell)["reason"])
	_refresh_all()

func _unhandled_input(e : InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_B:
			_set_mode(not build_mode)
		elif e.keycode == KEY_E and not build_mode and not _target.is_empty():
			_target["ref"].interact(player)
		elif build_mode and e.keycode == KEY_R:
			_rotate()
	elif e is InputEventMouseButton and e.pressed and build_mode:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_place()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_remove()

func _on_pickup_done(r : Dictionary) -> void:
	msg.text = PICK_MSG.get(r["reason"], "เก็บไม่ได้: " + String(r["reason"]))

func _process(_d : float) -> void:
	var st : Array = StationFinder.available(db, grid, player.global_position)
	if st != _stations:
		_stations = st
		_refresh_craft()
		_refresh_salvage()
	if build_mode:
		_cell = BuildConst.world_to_cell(get_global_mouse_position())
		_ghost = grid.check(db, sel_id, _cell, rot) if sel_id != &"" else {}
		if _ghost.is_empty():
			hint.text = "เลือกชิ้นส่วนจากแถบด้านบน"
		else:
			hint.text = "วางได้" if _ghost["ok"] else "วางไม่ได้: " + REASONS.get(_ghost["reason"], String(_ghost["reason"]))
		_target = {}
	else:
		var c : Array = []
		for pk in get_tree().get_nodes_in_group("pickup"):
			if is_instance_valid(pk) and not pk.is_queued_for_deletion():
				c.append({"kind": InteractPick.KIND_PICKUP, "pos": pk.global_position, "ref": pk})
		_target = InteractPick.pick(player.global_position, player.get_facing(), c)
	if _target.is_empty():
		prompt.text = ""
	else:
		var pk2 : Pickup = _target["ref"]
		prompt.text = "E: เก็บ %s x%d" % [_name(pk2.item_id), pk2.amount]
	queue_redraw()

func _rect(cell : Vector2i, fp : Vector2i) -> Rect2:
	return Rect2(BuildConst.cell_to_world(cell), Vector2(fp * BuildConst.CELL_SIZE))

func _draw() -> void:
	var sz : Vector2 = Vector2(grid.size * BuildConst.CELL_SIZE)
	var a : float = 0.25 if build_mode else 0.08
	for x in range(grid.size.x + 1):
		draw_line(Vector2(x * BuildConst.CELL_SIZE, 0), Vector2(x * BuildConst.CELL_SIZE, sz.y), Color(1, 1, 1, a))
	for y in range(grid.size.y + 1):
		draw_line(Vector2(0, y * BuildConst.CELL_SIZE), Vector2(sz.x, y * BuildConst.CELL_SIZE), Color(1, 1, 1, a))
	var items : Array = grid.all_structs()
	for pass_layer in [BuildGrid.LAYER_FLOOR, BuildGrid.LAYER_OBJECT]:
		for s in items:
			var p : BuildingPieceData = db.get_item(StringName(s["piece"])) as BuildingPieceData
			if p == null or BuildGrid.layer_of(p) != pass_layer:
				continue
			var r : Rect2 = _rect(s["cell"], BuildGrid.footprint(p, s["rot"]))
			draw_rect(r, CAT_COLORS[p.category])
			draw_rect(r, Color.BLACK, false, 1.0)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 14), p.display_name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	if build_mode and not _ghost.is_empty():
		var gp : BuildingPieceData = db.get_item(sel_id) as BuildingPieceData
		var gr : Rect2 = _rect(_cell, BuildGrid.footprint(gp, rot))
		var col : Color = Color(0.2, 1, 0.3) if _ghost["ok"] else Color(1, 0.2, 0.2)
		draw_rect(gr, Color(col, 0.4))
		draw_rect(gr, col, false, 2.0)
		if not _ghost["ok"]:
			draw_line(gr.position, gr.end, col, 2.0)
			draw_line(Vector2(gr.position.x, gr.end.y), Vector2(gr.end.x, gr.position.y), col, 2.0)
	if not build_mode:
		var o : Vector2 = player.global_position
		draw_line(o, o + player.get_facing() * InteractPick.RANGE, Color(1, 1, 0, 0.6), 2.0)
		if not _target.is_empty():
			draw_arc(_target["pos"], 14.0, 0, TAU, 24, Color(1, 1, 0), 2.0)
