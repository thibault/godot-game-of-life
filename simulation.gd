class_name Simulation extends RefCounted

var grid_size: int
var pipeline: ShaderTools.Pipeline

var do_splat: bool = false
var splat_coords: Vector2

func _init(_grid_size: int, _cells: PackedByteArray) -> void:
	grid_size = _grid_size

	pipeline = ShaderTools.Pipeline.new(Vector2(grid_size, grid_size), "res://shaders/")

	pipeline.add_texture_buffer("cells",  RenderingDevice.DATA_FORMAT_R32_SFLOAT, _cells)
	pipeline.add_byte_buffer("splat", [])

	pipeline.add_step(
		"splat",
		{0: "splat", 1: "cells"},
		Callable(self, "simple_push_constant")
	)
	pipeline.add_step(
		"iterate",
		{0: "cells"},
		Callable(self, "simple_push_constant")
	)
	
func step(delta: float):
	if do_splat:
		var splat_data = PackedByteArray()
		splat_data.resize(4 * 2)
		splat_data.encode_float(0, splat_coords[0])
		splat_data.encode_float(4, splat_coords[1])
		pipeline.update_buffer_data("splat", splat_data)
		pipeline.run("splat", delta, ["cells"])

	pipeline.run("iterate", delta, ["cells"])

func simple_push_constant(delta: float) -> PackedByteArray:
	var push_constant := PackedFloat32Array()
	push_constant.push_back(grid_size)
	push_constant.push_back(grid_size)
	push_constant.push_back(delta)
	push_constant.push_back(0.0)
	return push_constant.to_byte_array()

func splat(coords: Vector2) -> void:
	do_splat = true
	splat_coords = coords

func unsplat() -> void:
	do_splat = false

func get_texture_rid(tex: String) -> RID:
	return pipeline.get_texture_rid(tex)
