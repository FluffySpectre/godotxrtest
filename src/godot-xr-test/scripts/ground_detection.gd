class_name GroundDetection extends RayCast3D

# How far to cast the ray for ground detection
@export var detection_distance: float = 10.0

# Whether we've found a valid ground surface
var ground_detected: bool = false
var ground_normal: Vector3 = Vector3.UP
var ground_position: Vector3

func _ready():
    # Configure the ray
    target_position = Vector3(0, -detection_distance, 0)
    enabled = true
    collision_mask = 1  # Set this to your ground/environment layer

func _physics_process(_delta):
    # Update ground detection
    if is_colliding():
        ground_detected = true
        ground_normal = get_collision_normal()
        ground_position = get_collision_point()
    else:
        ground_detected = false

# Function to check if position is on a valid ground
func is_valid_placement_position(position: Vector3) -> bool:
    # Move the ray to the position
    global_transform.origin = position
    
    # Wait for physics to update
    await get_tree().physics_frame
    
    # Check if we hit something
    return ground_detected and ground_normal.dot(Vector3.UP) > 0.7  # Ensures surface is relatively flat
    
