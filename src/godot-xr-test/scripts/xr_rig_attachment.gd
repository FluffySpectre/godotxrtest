class_name XRRigAttachment extends Node

@export var attachment_point: XRRig.AttachmentPoint

var _is_attached: bool = false

func _process(_delta: float) -> void:
  if _is_attached:
    return
  _try_attach_to_rig()

func _try_attach_to_rig() -> void:
  if not XRRig.instance:
    return
  
  var attachment_node = XRRig.instance.get_attachment_point_node(attachment_point)
  get_parent().reparent(attachment_node, false)
  
  _is_attached = true
