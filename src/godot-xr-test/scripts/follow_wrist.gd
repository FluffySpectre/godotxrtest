class_name FollowWrist extends Node

@export var offset: Vector3 = Vector3.ZERO

@onready var _parent: Node3D = get_parent()

var _xr_origin: XROrigin3D
var _xr_controller: XRController3D
var _hand: OpenXRInterface.Hand
var _xr_interface: XRInterface

func _ready() -> void:
  _xr_interface = XRServer.find_interface("OpenXR")
  find_xr_nodes()

func _process(delta):
  var oxrjps = get_oxr_joint_positions()
  var xrt = _xr_origin.global_transform
  var wrist_origin = xrt * oxrjps[OpenXRInterface.HAND_JOINT_WRIST]
  
  _parent.global_position = offset + wrist_origin

func get_oxr_joint_positions():
  var oxrjps = []
  for j in range(OpenXRInterface.HAND_JOINT_MAX):
    oxrjps.push_back(_xr_interface.get_hand_joint_position(_hand, j))
  return oxrjps

func find_xr_nodes():
  # first go up the tree to find the controller and origin
  var nd = self
  while nd != null and not (nd is XRController3D):
    nd = nd.get_parent()
  if nd == null:
    print("Warning, no controller node detected")
    return false
  _xr_controller = nd
  
  while nd != null and not (nd is XROrigin3D):
    nd = nd.get_parent()
  if nd == null:
    print("Warning, no xrorigin node detected")
    return false
  _xr_origin = nd

  # Finally decide if it is left or right hand and test consistency in the API
  var islefthand = (_xr_controller.tracker == "left_hand")
  _hand = OpenXRInterface.Hand.HAND_LEFT if islefthand else OpenXRInterface.Hand.HAND_RIGHT

  return true
