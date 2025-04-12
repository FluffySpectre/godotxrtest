class_name WireframeBox extends MeshInstance3D

var _material: Material
var _size: Vector3 = Vector3(1, 1, 1)

func _init(material: Material, size: Vector3 = Vector3(1, 1, 1)):
    _material = material
    _size = size
    update_box()

func _ready():
    # If this node is added to the scene through the editor, update it
    update_box()

func set_box_size(size: Vector3) -> void:
    _size = size
    update_box()
    
func update_box() -> void:
    # Create a new ImmediateMesh instance
    var im = ImmediateMesh.new()
    mesh = im
    
    # Set the material for the lines
    material_override = _material
    
    # Calculate the half-extents of the box
    var half_size = _size / 2
    
    # Begin drawing lines
    im.surface_begin(Mesh.PRIMITIVE_LINES)
    
    # Define the 8 vertices of the box
    var v0 = Vector3(-half_size.x, -half_size.y, -half_size.z)
    var v1 = Vector3(half_size.x, -half_size.y, -half_size.z)
    var v2 = Vector3(half_size.x, -half_size.y, half_size.z)
    var v3 = Vector3(-half_size.x, -half_size.y, half_size.z)
    var v4 = Vector3(-half_size.x, half_size.y, -half_size.z)
    var v5 = Vector3(half_size.x, half_size.y, -half_size.z)
    var v6 = Vector3(half_size.x, half_size.y, half_size.z)
    var v7 = Vector3(-half_size.x, half_size.y, half_size.z)
    
    # Bottom face edges
    im.surface_add_vertex(v0)
    im.surface_add_vertex(v1)
    
    im.surface_add_vertex(v1)
    im.surface_add_vertex(v2)
    
    im.surface_add_vertex(v2)
    im.surface_add_vertex(v3)
    
    im.surface_add_vertex(v3)
    im.surface_add_vertex(v0)
    
    # Top face edges
    im.surface_add_vertex(v4)
    im.surface_add_vertex(v5)
    
    im.surface_add_vertex(v5)
    im.surface_add_vertex(v6)
    
    im.surface_add_vertex(v6)
    im.surface_add_vertex(v7)
    
    im.surface_add_vertex(v7)
    im.surface_add_vertex(v4)
    
    # Connecting edges between top and bottom faces
    im.surface_add_vertex(v0)
    im.surface_add_vertex(v4)

    im.surface_add_vertex(v1)
    im.surface_add_vertex(v5)
    
    im.surface_add_vertex(v2)
    im.surface_add_vertex(v6)

    im.surface_add_vertex(v3)
    im.surface_add_vertex(v7)
    
    im.surface_end()
