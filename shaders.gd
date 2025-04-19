class_name ShaderTools extends Node

# XXX TODO add rid clearing code

# Represents a single buffer containing data manipulated by a shader
class Buffer:
	var size: Vector2
	var format: RenderingDevice.DataFormat
	var texture: RID
	var sampler: RID
	var in_uniform: RDUniform
	var out_uniform: RDUniform

	func _init(_size: Vector2, _format: RenderingDevice.DataFormat, _data: PackedByteArray) -> void:
		size = _size
		format = _format
		texture = _create_texture(_data)
		sampler = _create_sampler()
		in_uniform = _create_in_uniform()
		out_uniform = _create_out_uniform()

	func _create_texture(data: PackedByteArray) -> RID:
		var tf: RDTextureFormat = RDTextureFormat.new()
		tf.format = format
		tf.width = size.x
		tf.height = size.y
		tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
		tf.depth = 1
		tf.array_layers = 1
		tf.mipmaps = 1
		tf.usage_bits = (
				RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
				RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
				RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
				RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
				RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
				RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
		)
		var rd := RenderingServer.get_rendering_device()
		var rid
		if data:
			rid = rd.texture_create(tf, RDTextureView.new(), [data])
		else:
			rid = rd.texture_create(tf, RDTextureView.new(), [])
			rd.texture_clear(rid, Color(0, 0, 0, 0), 0, 1, 0, 1)

		return rid

	func _create_sampler() -> RID:
		var sampler_state := RDSamplerState.new()
		sampler_state.unnormalized_uvw = true
		sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler_state.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		var rd := RenderingServer.get_rendering_device()
		var sampler = rd.sampler_create(sampler_state)
		return sampler

	# Create the uniform for a sampler2D
	func _create_in_uniform() -> RDUniform:
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform.add_id(sampler)
		uniform.add_id(texture)
		return uniform

	# Create the uniform object for a writeable image2D object
	func _create_out_uniform() -> RDUniform:
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.add_id(texture)
		return uniform

	# Get the uniform for the buffer as input data (with sampling)
	func get_in_uniform(binding: int) -> RDUniform:
		var uniform: RDUniform = in_uniform
		uniform.binding = binding
		return uniform

	func get_out_uniform(binding: int) -> RDUniform:
		var uniform: RDUniform = out_uniform
		uniform.binding = binding
		return uniform


# Represents a single data with a ping-pong buffer for shader in/out manipulation
class DoubleBuffer:
	var size: Vector2
	var input: Buffer
	var output: Buffer

	func _init(_size: Vector2, _format: RenderingDevice.DataFormat, _data: PackedByteArray) -> void:
		size = _size
		input = Buffer.new(_size, _format, _data)
		output = Buffer.new(_size, _format, [])

	func swap() -> void:
		var tmp: Buffer
		tmp = input
		input = output
		output = tmp

	func get_uniform_set(shader: RID, shader_set: int) -> RID:
		var in_uniform := input.get_in_uniform(0)
		var out_uniform := output.get_out_uniform(1)
		var rd := RenderingServer.get_rendering_device()
		var uniform_set = rd.uniform_set_create([in_uniform, out_uniform], shader, shader_set)
		return uniform_set

	func get_texture_rid() -> RID:
		return input.texture

	func clear_texture() -> void:
		var rd := RenderingServer.get_rendering_device()
		rd.texture_clear(input.texture, Color(0, 0, 0, 0), 0, 1, 0, 1)


# A simple object to build a uniform set from a byte array
class ByteBuffer:
	var data: PackedByteArray

	func _init(_data: PackedByteArray) -> void:
		data = _data

	func get_uniform_set(shader: RID, shader_set: int) -> RID:
		var rd := RenderingServer.get_rendering_device()
		var buffer := rd.storage_buffer_create(data.size(), data)

		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniform.binding = 0
		uniform.add_id(buffer)

		var uniform_set := rd.uniform_set_create([uniform], shader, shader_set)
		return uniform_set


class ComputeShader:
	var rd: RenderingDevice
	var shader: RID
	var pipeline: RID
	var buffers: Dictionary[int, Variant]
	var get_push_constant: Callable
	var x_groups: int
	var y_groups: int

	func _init(_shader_path: String, _size: Vector2, _buffers: Dictionary[int, Variant], _get_push_constant: Callable) -> void:

		buffers = _buffers
		get_push_constant = _get_push_constant

		@warning_ignore("integer_division")
		x_groups = (_size.x - 1) / 8 + 1
		@warning_ignore("integer_division")
		y_groups = (_size.y - 1) / 8 + 1

		rd = RenderingServer.get_rendering_device()
		var shader_file := load(_shader_path)
		var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
		shader = rd.shader_create_from_spirv(shader_spirv)
		pipeline = rd.compute_pipeline_create(shader)

	func set_buffers(_buffers: Dictionary[int, Variant]) -> void:
		buffers = _buffers

	func run(delta: float) -> void:
		var push_constant = get_push_constant.call(delta)
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

		var uniform_sets: Array[RID]
		for buffer_id in buffers:
			var uniform_set = buffers[buffer_id].get_uniform_set(shader, buffer_id)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, buffer_id)
			uniform_sets.append(uniform_set)

		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()

		for us in uniform_sets:
			rd.free_rid(us)


class Pipeline:
	var size: Vector2
	var shaders_dir: String
	var buffers: Dictionary[String, Variant]
	var shaders: Dictionary[String, ComputeShader]

	func _init(_size: Vector2, _dir: String) -> void:
		size = _size
		shaders_dir = _dir

	func add_texture_buffer(name: String, format: RenderingDevice.DataFormat, data: PackedByteArray) -> void:
		var buffer = DoubleBuffer.new(size, format, data)
		buffers[name] = buffer

	func add_byte_buffer(name: String, data: PackedByteArray) -> void:
		var buffer = ByteBuffer.new(data)
		buffers[name] = buffer

	func update_buffer_data(name: String, data: PackedByteArray) -> void:
		buffers[name].data = data

	func clear_buffer(name: String) -> void:
		buffers[name].clear_texture()

	func get_texture_rid(name: String) -> RID:
		return buffers[name].get_texture_rid()

	func add_step(name: String, _buffers: Dictionary[int, String], get_push_constant: Callable) -> void:
		var shader_path = "%s%s.glsl" % [shaders_dir, name]
		var shader_buffers: Dictionary[int, Variant] = {}
		for shader_id in _buffers:
			shader_buffers[shader_id] = buffers[_buffers[shader_id]]
		shaders[name] = ComputeShader.new(shader_path, size, shader_buffers, get_push_constant)

	func run(step: String, delta: float, to_swap: Array[String]) -> void:
		var shader = shaders[step]
		shader.run(delta)
		for buffer_name in to_swap:
			buffers[buffer_name].swap()
