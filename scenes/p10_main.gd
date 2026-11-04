extends Node


func _ready() -> void:
	CraftTests.new().run_all()
	InventoryTests.new().run_all()
	BuildGridTests.new().run_all()
	InteractPickTests.new().run_all()
