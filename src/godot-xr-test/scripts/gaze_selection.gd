class_name GazeSelection extends Node3D

# Reference to the XR camera (head)
@export var xr_camera: XRCamera3D

# Maximum distance for the gaze ray
@export var max_distance: float = 5.0

# Layer mask for interactable objects
@export_flags("Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5") var interaction_mask: int = 1

# Reference to the currently selected object
var selected_object: InteractableObject = null

func _ready():
    print("GazeSelection initialized with camera: ", xr_camera.name if xr_camera else "None")

func _physics_process(_delta):
    # Update selection based on camera gaze
    _update_selection()

func _update_selection():
    if !xr_camera:
        return
    
    # Cast a ray from the camera center
    var from = xr_camera.global_transform.origin
    var to = from + (-xr_camera.global_transform.basis.z * max_distance)
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = interaction_mask
    
    # Allow ray to hit areas (in case InteractableObjects use Area3D)
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)
    
    var new_selection = null
    
    if result and result.collider:
        # Try to find the InteractableObject parent
        var current = result.collider
        while current and not current is InteractableObject:
            current = current.get_parent()
        
        if current is InteractableObject:
            new_selection = current
    
    # Update selection if changed
    if new_selection != selected_object:
        # Deselect current object
        if selected_object:
            selected_object.set_selected(false)
        
        # Select new object
        selected_object = new_selection
        if selected_object:
            selected_object.set_selected(true)
  
