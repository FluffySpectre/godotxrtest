class_name Toolbox extends Node3D

@export var zone_count: int = 3
@export var radius: float = 0.1
@export var arc_degrees: float = 80.0
@export var snapping_zone_scene: PackedScene
@export var initial_objects: Array[InteractableObject]

@onready var _zone_container: Node3D = $Contents/ZoneContainer

var _zones: Dictionary[int, SnappingZone] = {}

func _ready() -> void:
  _setup_snapping_zones()
  await get_tree().process_frame
  _setup_initial_objects()

func _setup_snapping_zones() -> void:
  # Create new zones in arc layout
  for i in range(zone_count):
    _create_zone_at_index(i)

func _create_zone_at_index(index: int) -> void:
  var zone = snapping_zone_scene.instantiate() as SnappingZone
  zone.position = Utils.get_arc_position(index, zone_count, radius, arc_degrees)
  zone.object_snapped.connect(_on_object_snapped.bind(zone))
  zone.object_unsnapped.connect(_on_object_unsnapped.bind(zone))
  _zone_container.add_child(zone)
  _zones[index] = zone

func _setup_initial_objects() -> void:
  if initial_objects.size() == 0:
    return
  
  var current_zone: int = 0
  for obj in initial_objects:
    obj._snap_to_zone(_zones[current_zone], false)
    current_zone += 1

func _on_object_snapped(obj: InteractableObject, zone: SnappingZone) -> void:
  if !zone.has_node("ObjectLabel"):
    return
  var label = zone.get_node("ObjectLabel") as Label3D
  label.text = obj.object_name
  label.position = obj.snap_label_offset
  
func _on_object_unsnapped(obj: InteractableObject, zone: SnappingZone) -> void:
  if !zone.has_node("ObjectLabel"):
    return
  var label = zone.get_node("ObjectLabel") as Label3D
  label.text = ""
