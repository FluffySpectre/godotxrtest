class_name Fade extends Node3D

var _faders: Dictionary = {}
var _update: bool = false
var _mesh: MeshInstance3D
var _material: ShaderMaterial

func _ready() -> void:
  # Add to the fade_mesh group
  add_to_group("fade_mesh")

  # Get the mesh and material
  _mesh = $FadeMesh
  _material = _mesh.get_surface_override_material(0)

func _process(_delta : float) -> void:
  # Skip if nothing to update
  if not _update:
    return

  # Calculate the cumulative shade color
  var fade := Color(1, 1, 1, 0)
  var show_mesh := false
  for whom in _faders:
    var color := _faders[whom] as Color
    fade = fade.blend(color)
    show_mesh = true

  # Set the shader and show if necessary
  _material.set_shader_parameter("albedo", fade)
  _mesh.visible = show_mesh
  _update = false

func set_fade_level(whom: Variant, color: Color) -> void:
  # Test if fading is needed
  if color.a > 0:
    # Set the fade level
    _faders[whom] = color
    _update = true
  elif _faders.erase(whom):
    # Fade erased
    _update = true

static func set_fade(whom: Variant, color: Color) -> void:
  var tree := Engine.get_main_loop() as SceneTree
  for node in tree.get_nodes_in_group("fade_mesh"):
    var fade := node as Fade
    if fade:
      fade.set_fade_level(whom, color)
