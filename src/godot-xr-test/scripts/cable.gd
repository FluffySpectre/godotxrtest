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
  
  # Calculate direction and perpendicular vectors
  var direction = (end_pos - start_pos).normalized()
  var up = Vector3.UP
  if abs(direction.dot(up)) > 0.9:
    up = Vector3.RIGHT
  var right = direction.cross(up).normalized() * cable_thickness
  var forward = right.cross(direction).normalized() * cable_thickness
  
  # Create vertices for a rectangular tube
  var vertices = PackedVector3Array()
  var normals = PackedVector3Array()
  var uvs = PackedVector2Array()
  var indices = PackedInt32Array()
  
  # Create 8 vertices (4 at start, 4 at end)
  var vertex_positions = [
    start_pos + right + forward,   # 0
    start_pos + right - forward,   # 1
    start_pos - right - forward,   # 2
    start_pos - right + forward,   # 3
    end_pos + right + forward,     # 4
    end_pos + right - forward,     # 5
    end_pos - right - forward,     # 6
    end_pos - right + forward      # 7
  ]
  
  # Define face normals for each side
  var face_normals = [
    right.normalized(),           # Right side
    -forward.normalized(),        # Back side  
    -right.normalized(),          # Left side
    forward.normalized(),         # Front side
    -direction.normalized(),      # Start cap
    direction.normalized()        # End cap
  ]
  
  # Create faces
  var faces = [
    [0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7], # sides
    [3,2,1,0], [4,5,6,7] # caps
  ]
  
  var vertex_index = 0
  
  for face_idx in range(faces.size()):
    var face = faces[face_idx]
    var normal = face_normals[face_idx]
    
    # Add vertices for this face
    var face_start_idx = vertex_index
    
    for i in range(4):
      vertices.append(vertex_positions[face[i]])
      normals.append(normal)
      # Create UV coordinates
      uvs.append(Vector2(float(i % 2), float(i / 2)))
    
    # First triangle
    indices.append(face_start_idx + 0)
    indices.append(face_start_idx + 1)
    indices.append(face_start_idx + 2)
    
    # Second triangle
    indices.append(face_start_idx + 0)
    indices.append(face_start_idx + 2)
    indices.append(face_start_idx + 3)
    
    vertex_index += 4
  
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
      update_line()
      _last_start_pos = current_start_pos
      _last_end_pos = current_end_pos
