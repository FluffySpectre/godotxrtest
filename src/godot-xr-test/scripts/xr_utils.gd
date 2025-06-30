class_name XRUtils

static func get_xr_origin(node: Node) -> XROrigin3D:
  var origin: XROrigin3D
  
  # Walk up the tree from the provided node looking for the origin
  var current_node = node
  while current_node != null:
    if current_node is XROrigin3D:
      return current_node
    current_node = current_node.get_parent()

  # Check the children of the node
  for child in node.get_children():
    if child is XROrigin3D:
      return child

  # Could not find origin
  return null

static func get_xr_camera(node: Node) -> XRCamera3D:
  # Get the origin
  var origin := get_xr_origin(node)
  if !origin:
    return null

  # Attempt to get by the default name
  var camera = origin.get_node_or_null("XRCamera3D") as XRCamera3D
  if camera:
    return camera

  # Could not find camera
  return null
