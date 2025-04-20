class_name Simulation extends RefCounted

var grid_size: int

# This is our custom shader management tool
var pipeline: ShaderTools.Pipeline

# Setup the grid drawing
var do_splat: bool = false
var splat_coords: Vector2

func _init(_grid_size: int) -> void:
	grid_size = _grid_size

	# Let's instenciate our shader management tool.
	# It was made in a way so that all shaders that it will use must be stored in the
	# same directory
	pipeline = ShaderTools.Pipeline.new(Vector2(grid_size, grid_size), "res://shaders/")

	# Create a texture buffer, that will hold the cellular automata's current state.
	# This will actually create two textures (one for input, one for output) that will
	# swapped every iterations.
	#
	# We need to configure the texture format. Here, we create a texture with a single
	# floating point channel, since a cell can only be black or white.
	# In different use cases, textures can hold up to four channels (rgba).
	# 
	# We can also configure the sampling mode. See RenderingDevice doc for more details.
	pipeline.add_texture_buffer("cells",  RenderingDevice.DATA_FORMAT_R32_SFLOAT, [], RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT)
	
	# We create a byte buffer that we use to tell the shader where we are drawing
	pipeline.add_byte_buffer("splat", [])

	# Now, let's define the different steps.
	# Since it's a very simple simulation, we use only two shaders.
	# One for drawing on the grid, one for running the actual simulation
	
	# For every step, we tell :
	#  - which shader to use
	#  - which buffers to pass to the shaders as uniforms.
	#    you need to match the dictionnary keys with the `set` parameter in the shader.
	#  - which method to use to build a "push constant"
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
	
# Run a single step of the pipeline
func step(delta: float):
	if do_splat:
		# Build the splat buffer that will be passed as the shader as a uniform
		var splat_data = PackedByteArray()
		splat_data.resize(4 * 2)
		splat_data.encode_float(0, splat_coords[0])
		splat_data.encode_float(4, splat_coords[1])
		pipeline.update_buffer_data("splat", splat_data)
		
		# Run a shader
		# The last paramater is the list of buffers that must be swapped.
		# Sometimes, a buffer is read-only so it must not be swapped.
		pipeline.run("splat", delta, ["cells"])

	pipeline.run("iterate", delta, ["cells"])

func simple_push_constant(delta: float) -> PackedByteArray:
	
	# Build an array that will be passed as the push constant
	# This array must follow glsl alignment rules, so the data has to be padded.
	var push_constant := PackedFloat32Array()
	push_constant.push_back(grid_size)
	push_constant.push_back(grid_size)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	return push_constant.to_byte_array()

func splat(coords: Vector2) -> void:
	do_splat = true
	splat_coords = coords

func unsplat() -> void:
	do_splat = false

# Fetch a given texture rid from the pipeline
func get_texture_rid(tex: String) -> RID:
	return pipeline.get_texture_rid(tex)
