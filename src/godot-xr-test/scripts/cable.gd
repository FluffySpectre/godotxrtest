class_name Cable extends Node3D

@export var start_node: Node3D
@export var end_node: Node3D
@export var cable_material: Material
@export var cable_thickness: float = 0.002

var _line_mesh_instance: MeshInstance3D
var _array_mesh: ArrayMesh
var _last_start_pos: Vector3
var _last_end_pos: Vector3

func _ready() -> void:
  _line_mesh_instance = MeshInstance3D.new()
  _line_mesh_instance.material_override = cable_material
  add_child(_line_mesh_instance)
  
  _array_mesh = ArrayMesh.new()
  _line_mesh_instance.mesh = _array_mesh
  
  if start_node && end_node:
    _last_start_pos = start_node.global_position
    _last_end_pos = end_node.global_position
  
  # Create initial line
  update_line()

func update_line() -> void:
  if !start_node || !end_node:
    return
  
  _array_mesh.clear_surfaces()
  
  var start_pos = to_local(start_node.global_position)
  var end_pos = to_local(end_node.global_position)
  
  var camera = get_viewport().get_camera_3d()
  if !camera:
    return
    
  var camera_pos = to_local(camera.global_position)
  
  # Calculate cable direction and center
  var cable_direction = (end_pos - start_pos)
  var cable_center = (start_pos + end_pos) * 0.5
  var cable_length = cable_direction.length()
  
  if cable_length == 0:
    return
    
  cable_direction = cable_direction.normalized()
  
  # Calculate right vector for billboarding
  var to_camera = (camera_pos - cable_center).normalized()
  var right = cable_direction.cross(to_camera).normalized() * cable_thickness
  
  var vertices = PackedVector3Array()
  var normals = PackedVector3Array()
  var uvs = PackedVector2Array()
  var indices = PackedInt32Array()
  
  # Quad vertices
  vertices.append(start_pos - right)  # 0
  vertices.append(start_pos + right)  # 1
  vertices.append(end_pos + right)    # 2
  vertices.append(end_pos - right)    # 3
  
  # All normals point toward camera
  for i in range(4):
    normals.append(to_camera)
  
  # UV coordinates
  uvs.append(Vector2(0, 0))
  uvs.append(Vector2(1, 0))
  uvs.append(Vector2(1, 1))
  uvs.append(Vector2(0, 1))
  
  # Two triangles for the quad
  indices.append_array([0, 1, 2, 0, 2, 3])
  
  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  arrays[Mesh.ARRAY_TEX_UV] = uvs
  arrays[Mesh.ARRAY_INDEX] = indices
  
  _array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _process(_delta: float) -> void:
  # Only update if positions changed
  if start_node && end_node:
    var current_start_pos = start_node.global_position
    var current_end_pos = end_node.global_position
    
    if current_start_pos != _last_start_pos || current_end_pos != _last_end_pos:
      update_line.call_deferred() # Update at the end of the frame, to ensure the position updates from our parent are done
      _last_start_pos = current_start_pos
      _last_end_pos = current_end_pos
