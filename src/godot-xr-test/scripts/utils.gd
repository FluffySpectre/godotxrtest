class_name Utils

static func get_arc_position(index: int, item_count: int, radius: float, arc_degrees: float) -> Vector3:
  if item_count <= 1:
    return Vector3(radius, 0.0, 0)
  
  # Calculate angle for this item in the arc
  var start_angle = -arc_degrees / 2.0
  var end_angle = arc_degrees / 2.0
  var angle_step = (end_angle - start_angle) / (item_count - 1)
  var angle_degrees = start_angle + (angle_step * index)
  var angle_rad = deg_to_rad(angle_degrees)
  
  var x = cos(angle_rad) * radius
  var z = sin(angle_rad) * radius
  
  return Vector3(x, 0.0, z)

static func get_mesh_bounds(root_node: Node) -> Vector3:
  if !root_node:
    return Vector3.ZERO
  
  var aabb = AABB()
  var found_mesh = false
  
  for child in root_node.get_children():
    if child is MeshInstance3D:
      var mesh_instance = child as MeshInstance3D
      if mesh_instance.mesh:
        var local_aabb = mesh_instance.get_aabb()
        local_aabb = mesh_instance.transform * local_aabb
        
        if !found_mesh:
          aabb = local_aabb
          found_mesh = true
        else:
          aabb = aabb.merge(local_aabb)
  
  return aabb.size * root_node.scale
