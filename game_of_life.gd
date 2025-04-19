@tool
extends MeshInstance3D

var grid_size: int = 128
var cells: Texture2DRD
var simulation: Simulation

func _ready() -> void:
	cells = Texture2DRD.new()
	mesh.material.set_shader_parameter("cells", cells)
	var data = PackedByteArray()
	data.resize(grid_size * grid_size)
	data.fill(0)
	simulation = Simulation.new(grid_size, PackedByteArray())
	
func _physics_process(delta: float) -> void:
	RenderingServer.call_on_render_thread(_render_process.bind(delta))

func _render_process(delta: float) -> void:
	if simulation:
		var a = Time.get_ticks_msec()
		simulation.step(delta)
		cells.texture_rd_rid = simulation.get_texture_rid("cells")
		var b = Time.get_ticks_msec()
		
func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not simulation:
		return
		
	if event is InputEventMouseMotion:
		var x = event_position.x
		var y = event_position.z

		if event.pressure == 1.0:
			var half = grid_size / 2.0
			simulation.splat(Vector2(x + half, y + half))
		else:
			simulation.unsplat()
