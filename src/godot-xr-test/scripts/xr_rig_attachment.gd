class_name XRRigAttachment extends Node

## The attachment point to attach to
@export var attachment_point: XRRig.AttachmentPoint

@onready var _parent: Node3D = get_parent() as Node3D

var _attachment_node: Node3D

func _process(_delta: float) -> void:
  _follow_attachment_point()

func _follow_attachment_point() -> void:
  if !XRRig.instance:
    return
  if !_attachment_node:
    _attachment_node = XRRig.instance.get_attachment_point_node(attachment_point)
  if _attachment_node:
    _parent.global_position = _attachment_node.global_position
    _parent.global_rotation = _attachment_node.global_rotation

func change_attachment_point(new_attachment_point: XRRig.AttachmentPoint) -> void:
  attachment_point = new_attachment_point
  _attachment_node = XRRig.instance.get_attachment_point_node(attachment_point)
