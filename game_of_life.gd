@tool
extends MeshInstance3D

# This is our grid width and height
var grid_size: int = 256

# This is a special kind of texture that allows accessing textures
# created directly with a RenderingDevice, Godot's low-level rendering api.
var cells: Texture2DRD

# This class will run the game of life simulation
var simulation: Simulation

@onready var camera: Camera3D = $"../Camera3D"

func _ready() -> void:
	simulation = Simulation.new(grid_size)
	mesh.size = Vector2(grid_size, grid_size)
	camera.size = grid_size
	
	# Here, we will use the same texture for computing and for rendering
	cells = Texture2DRD.new()
	mesh.material.set_shader_parameter("cells", cells)
	
	
func _physics_process(delta: float) -> void:
	# We need access to the RenderingServer's inner data, but it's running
	# in it's own thread. Thus, we need to process the simulation on the render thread.
	RenderingServer.call_on_render_thread(_render_process.bind(delta))

func _render_process(delta: float) -> void:
	if simulation:
		# Run a single game of life simulation
		simulation.step(delta)
		
		# Since we use a ping-pong buffer, the input became the output, etc.
		# Thus, we need to update the rendering texture's rid, so it's pointing
		# to the right data
		cells.texture_rd_rid = simulation.get_texture_rid("cells")
		
func _unhandled_input(event: InputEvent) -> void:
	if not simulation:
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	if event is InputEventMouseMotion:
		var coords = event.position * grid_size / viewport_size

		# Tell the grid to draw on the grid when we click on it
		if event.pressure == 1.0:
			var half = grid_size / 2.0
			simulation.splat(coords)
		else:
			# Cancel grid drawing
			simulation.unsplat()
