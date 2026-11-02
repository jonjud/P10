extends Node


func _ready() -> void:
	CraftTests.new().run_all()
