class_name GroundDetection extends RayCast3D

## How far to cast the ray for ground detection
@export var detection_distance: float = 10.0

var ground_detected: bool = false
var ground_normal: Vector3 = Vector3.UP
var ground_position: Vector3

func _ready() -> void:
  # Configure the ray
  position.y = 0.1
  target_position = Vector3(0, -detection_distance, 0)
  enabled = true
  hit_back_faces = false
  collision_mask = 16 # Layer 5

func _physics_process(_delta: float) -> void:
  # Update ground detection
  if is_colliding():
    ground_detected = true
    ground_normal = get_collision_normal()
    ground_position = get_collision_point()
  else:
    ground_detected = false
