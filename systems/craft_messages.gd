extends RefCounted
class_name CraftMessages

const TEXT : Dictionary = {
	CraftResult.OK: "",
	CraftResult.NOT_ENOUGH: "วัตถุดิบไม่พอ",
	CraftResult.WRONG_STATION: "ต้องอยู่ใกล้สถานีที่ใช้",
	CraftResult.OUTPUT_FULL: "กระเป๋าเต็ม ใส่ของที่ได้ไม่พอ",
	CraftResult.BAD_RECIPE: "สูตรนี้ใช้ไม่ได้",
	CraftResult.UNKNOWN_RECIPE: "ไม่พบสูตร",
	CraftResult.INVALID_QUANTITY: "จำนวนไม่ถูกต้อง",
	CraftResult.NOT_SALVAGEABLE: "ของชิ้นนี้ salvage ไม่ได้",
	CraftResult.NO_SALVAGE_DATA: "ไม่มีข้อมูล salvage",
}

static func of(reason : StringName) -> String:
	return TEXT.get(reason, "ทำไม่ได้: " + String(reason))
