class_name ToggleOnHandPose extends Node

@export var hand: String = "left"

var _parent: Node3D

func _ready() -> void:
  _parent = get_parent() as Node3D
  InteractionZoneManager.instance.hand_pose_started.connect(_on_hand_pose_started)
  InteractionZoneManager.instance.hand_pose_ended.connect(_on_hand_pose_ended)
  
func _on_hand_pose_started(hand_name: String) -> void:
  if hand != hand_name:
    return
  _parent.visible = true
  _parent.process_mode = Node.PROCESS_MODE_INHERIT
  
func _on_hand_pose_ended(hand_name: String) -> void:
  if hand != hand_name:
    return 
  _parent.visible = false
  _parent.process_mode = Node.PROCESS_MODE_DISABLED
