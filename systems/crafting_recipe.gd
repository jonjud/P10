extends Resource
class_name CraftingRecipe

@export var id : StringName
@export var display_name : String
@export var inputs : Array[RecipeIngredient] = []
@export var outputs : Array[RecipeOutput] = []
@export var station_required : StringName = &"hand"
@export var tier : int = 1
