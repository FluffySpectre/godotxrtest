class_name Cable extends Node3D

@export var start_node: Node3D
@export var end_node: Node3D
@export var cable_material: Material
@export var cable_thickness: float = 0.002

@export_group("Physics Settings")
@export var cable_segments: int = 8      # Number of segments
@export var gravity: float = 9.8         # Gravity strength
@export var stiffness: float = 5.0       # Spring stiffness between segments
@export var damping: float = 1.0         # Damping to reduce oscillation
@export var mass: float = 0.05           # Mass of each segment
@export var max_stretch: float = 0.5     # Maximum stretch allowed (multiplier of rest length)

@export_group("Flow Settings")
@export var enable_flow: bool = false
@export var cable_overlay_material: StandardMaterial3D
@export var dots_per_meter: float = 50.0
@export var flow_speed: float = 2.0

var _line_mesh_instance: MeshInstance3D
var _array_mesh: ArrayMesh
var _last_start_pos: Vector3
var _last_end_pos: Vector3
var _segment_positions: PackedVector3Array
var _segment_velocities: PackedVector3Array
var _rest_length: float
var _total_cable_length: float
var _camera: Camera3D
var _flow_timer: float

func _ready() -> void:
  _camera = get_viewport().get_camera_3d()
  
  _line_mesh_instance = MeshInstance3D.new()
  _line_mesh_instance.material_override = cable_material
  _line_mesh_instance.material_overlay = cable_overlay_material
  add_child(_line_mesh_instance)
  
  _array_mesh = ArrayMesh.new()
  _line_mesh_instance.mesh = _array_mesh
  
  _initialize_physics()
  
  if start_node && end_node:
    _last_start_pos = start_node.global_position
    _last_end_pos = end_node.global_position
  
  update_line()

func _initialize_physics() -> void:
  if !start_node || !end_node:
    return
    
  _segment_positions.resize(cable_segments + 2)  # +2 for start and end points
  _segment_velocities.resize(cable_segments + 2)
  
  var start_pos = start_node.global_position
  var end_pos = end_node.global_position
  var direct_distance = start_pos.distance_to(end_pos)
  
  # Make the cable slightly longer than the direct distance for natural sag
  _total_cable_length = direct_distance * 1.1
  _rest_length = _total_cable_length / (cable_segments + 1)
  
  # Initialize segment positions with slight sag
  for i in range(cable_segments + 2):
    var t = float(i) / (cable_segments + 1)
    var base_pos = start_pos.lerp(end_pos, t)
    
    # Add sag - more in the middle
    var sag_amount = sin(t * PI) * 0.1
    base_pos.y -= sag_amount
    
    _segment_positions[i] = base_pos
    _segment_velocities[i] = Vector3.ZERO

func _process(delta: float) -> void:
  if !enable_flow || !start_node || !end_node || !cable_overlay_material:
    _line_mesh_instance.material_overlay = null
    return
  
  _line_mesh_instance.material_overlay = cable_overlay_material
  
  var cable_length = _get_cable_length()
  var texture_repeats = cable_length * dots_per_meter
  cable_overlay_material.uv1_scale.x = texture_repeats
  
  # Animate the flow by offsetting UV coordinates
  _flow_timer += delta
  cable_overlay_material.uv1_offset.x = _flow_timer * flow_speed
  
  # Wrap timer
  if _flow_timer > 100.0:
    _flow_timer = fmod(_flow_timer, 1.0)

func _physics_process(delta: float) -> void:
  if !start_node || !end_node:
    return
    
  # Update endpoints
  var new_start_pos = start_node.global_position
  var new_end_pos = end_node.global_position
  
  var start_velocity = (new_start_pos - _segment_positions[0]) / delta if delta > 0 else Vector3.ZERO
  var end_velocity = (new_end_pos - _segment_positions[_segment_positions.size() - 1]) / delta if delta > 0 else Vector3.ZERO
  
  _segment_positions[0] = new_start_pos
  _segment_positions[_segment_positions.size() - 1] = new_end_pos
  
  # Transfer some velocity to adjacent segments for more realistic movement
  if cable_segments > 0:
    _segment_velocities[1] += start_velocity * 0.3
    _segment_velocities[_segment_positions.size() - 2] += end_velocity * 0.3
  
  # Apply physics to intermediate segments
  for i in range(1, _segment_positions.size() - 1):
    var force = Vector3.ZERO
    
    # Gravity
    force += Vector3.DOWN * gravity * mass
    
    # Spring forces to neighboring segments
    var prev_segment = _segment_positions[i - 1]
    var current_segment = _segment_positions[i]
    var next_segment = _segment_positions[i + 1]
    
    # Force from previous segment
    var to_prev = prev_segment - current_segment
    var prev_distance = to_prev.length()
    if prev_distance > 0:
      var prev_stretch = prev_distance - _rest_length
      var prev_force = to_prev.normalized() * prev_stretch * stiffness
      force += prev_force
    
    # Force from next segment
    var to_next = next_segment - current_segment
    var next_distance = to_next.length()
    if next_distance > 0:
      var next_stretch = next_distance - _rest_length
      var next_force = to_next.normalized() * next_stretch * stiffness
      force += next_force
    
    # Damping
    force -= _segment_velocities[i] * damping
    
    # Update velocity and position
    _segment_velocities[i] += force / mass * delta
    _segment_positions[i] += _segment_velocities[i] * delta
  
  # Prevent over-stretching
  _enforce_length_constraints()
  
  # Clear velocities for endpoints
  _segment_velocities[0] = Vector3.ZERO
  _segment_velocities[_segment_positions.size() - 1] = Vector3.ZERO
  
  update_line()

func _enforce_length_constraints() -> void:
  # Multiple passes to ensure all constraints are satisfied
  for p in range(2):
    for i in range(_segment_positions.size() - 1):
      var current_pos = _segment_positions[i]
      var next_pos = _segment_positions[i + 1]
      var distance = current_pos.distance_to(next_pos)
      var max_distance = _rest_length * max_stretch
      
      if distance > max_distance:
        var direction = (next_pos - current_pos).normalized()
        var correction = direction * (distance - max_distance)
        
        # Apply correction - more to the middle segments, less to endpoints
        if i == 0:
          # First segment - only move the next point
          _segment_positions[i + 1] -= correction
        elif i == _segment_positions.size() - 2:
          # Last segment - only move the current point
          _segment_positions[i] += correction
        else:
          # Middle segments - share the correction
          _segment_positions[i] += correction * 0.5
          _segment_positions[i + 1] -= correction * 0.5

func update_line() -> void:
  if !start_node || !end_node || _segment_positions.size() < 2:
    return
  
  _array_mesh.clear_surfaces()
  
  if !_camera:
    return
  
  var camera_pos = _camera.global_position
  
  var vertices = PackedVector3Array()
  var normals = PackedVector3Array()
  var uvs = PackedVector2Array()
  var indices = PackedInt32Array()
  
  # Convert global positions to local
  var local_positions = PackedVector3Array()
  for pos in _segment_positions:
    local_positions.append(to_local(pos))
  
  # Create quad strips between segments
  for i in range(local_positions.size() - 1):
    var start_pos = local_positions[i]
    var end_pos = local_positions[i + 1]
    var local_camera_pos = to_local(camera_pos)
    
    # Calculate direction and right vector for this segment
    var segment_direction = (end_pos - start_pos)
    if segment_direction.length() == 0:
      continue
      
    segment_direction = segment_direction.normalized()
    var to_camera = (local_camera_pos - (start_pos + end_pos) * 0.5).normalized()
    var right = segment_direction.cross(to_camera).normalized() * cable_thickness
    
    # Current vertex index offset
    var vertex_offset = vertices.size()
    
    # Add vertices for this segment
    vertices.append(start_pos - right)  # bottom left
    vertices.append(start_pos + right)  # bottom right
    vertices.append(end_pos + right)    # top right
    vertices.append(end_pos - right)    # top left
    
    # Normals point toward camera
    for j in range(4):
      normals.append(to_camera)
    
    # UV coordinates
    var u_start = float(i) / (local_positions.size() - 1)
    var u_end = float(i + 1) / (local_positions.size() - 1)
    uvs.append(Vector2(u_start, 0))
    uvs.append(Vector2(u_start, 1))
    uvs.append(Vector2(u_end, 1))
    uvs.append(Vector2(u_end, 0))
    
    # Two triangles for the quad
    indices.append_array([
      vertex_offset + 0, vertex_offset + 2, vertex_offset + 1,
      vertex_offset + 0, vertex_offset + 3, vertex_offset + 2
    ])
  
  if vertices.size() > 0:
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    
    _array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func reset_cable() -> void:
  _initialize_physics()

func _get_cable_length() -> float:
  var start_pos = start_node.global_position
  var end_pos = end_node.global_position
  return end_pos.distance_to(start_pos)
