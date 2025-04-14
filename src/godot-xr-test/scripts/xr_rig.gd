class_name XRRig extends XROrigin3D

enum AttachmentPoint {LEFT_HAND, RIGHT_HAND}

static var instance: XRRig

func _ready() -> void:
  instance = self

func get_attachment_point_node(attachment_point: AttachmentPoint) -> Node3D:
  if attachment_point == AttachmentPoint.LEFT_HAND:
    var xr_node = $LeftXRNode3D
    return xr_node.find_child("AttachmentPoint")
  elif attachment_point == AttachmentPoint.RIGHT_HAND:
    var xr_node = $RightXRNode3D
    return xr_node.find_child("AttachmentPoint")
  return null
