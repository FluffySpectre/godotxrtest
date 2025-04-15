class_name ToggleOnHandPose extends Node

@onready var interaction_zone_manager: InteractionZoneManager = $"/root/Main/XROrigin3D/InteractionZoneManager"

var _parent: Node3D

func _ready() -> void:
  _parent = get_parent() as Node3D
  interaction_zone_manager.connect("hand_pose_started", _on_hand_pose_started)
  interaction_zone_manager.connect("hand_pose_ended", _on_hand_pose_ended)

func _on_hand_pose_started(hand_name: String) -> void:
  _parent.visible = true
  _parent.process_mode = Node.PROCESS_MODE_INHERIT
  
func _on_hand_pose_ended(hand_name: String) -> void:
  _parent.visible = false
  _parent.process_mode = Node.PROCESS_MODE_DISABLED
