extends RefCounted
class_name CraftResult

const OK : StringName = &"ok"
const NULL_DB : StringName = &"null_db"
const NULL_INVENTORY : StringName = &"null_inventory"
const UNKNOWN_RECIPE : StringName = &"unknown_recipe"
const INVALID_QUANTITY : StringName = &"invalid_quantity"
const WRONG_STATION : StringName = &"wrong_station"
const NOT_ENOUGH : StringName = &"not_enough_quantity"
const OUTPUT_FULL : StringName = &"output_full"
const NOT_SALVAGEABLE : StringName = &"not_salvageable"
const NO_SALVAGE_DATA : StringName = &"no_salvage_data"
const BAD_RECIPE : StringName = &"bad_recipe"
const INTERNAL : StringName = &"internal"

static func make(reason : StringName, requested : int, done : int) -> Dictionary:
	return {"ok": reason == OK, "reason": reason, "requested": requested, "done": done, "remaining": maxi(0, requested - done)}
