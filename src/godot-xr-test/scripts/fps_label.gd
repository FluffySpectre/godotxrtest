class_name FPSLabel extends Label3D

# Update rate for the FPS display (in seconds)
var update_interval = 0.5
var time_passed = 0.0

func _ready():
  text = "FPS: 0"
  
  # Make sure the label always faces the camera
  billboard = BaseMaterial3D.BILLBOARD_ENABLED

  # Make text double-sided so it's readable from both sides
  double_sided = true

func _process(delta):
  # Accumulate time since last update
  time_passed += delta
  
  # Update text only after the interval has passed
  if time_passed >= update_interval:
    # Get and display FPS
    var current_fps = Engine.get_frames_per_second()
    text = "FPS: " + str(current_fps)
    time_passed = 0.0
