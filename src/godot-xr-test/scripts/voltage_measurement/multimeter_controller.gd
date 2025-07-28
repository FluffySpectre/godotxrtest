class_name MultimeterController extends Node3D

# Signals
signal measurement_started
signal measurement_ended
signal resistance_measurement_updated(resistance: float)

@export var update_rate: float = 0.25 # Measuring rate
@export var max_resistance: float = 10000.0 # Maximum resistance to measure (10 kOhm)
@export var resistance_step_size: float = 50.0  # Ohms per update step
@export var resistance_step_threshold: float = 1.0  # Minimum difference to continue stepping

@export_group("Flow Visualization")
@export var base_flow_speed: float = 2.0  # Base flow speed
@export var flow_speed_multiplier: float = 0.001  # How much resistance affects flow speed
@export var min_flow_speed: float = 0.5  # Minimum flow speed when measuring
@export var max_flow_speed: float = 5.0  # Maximum flow speed

# References
@onready var multimeter_object: InteractableObject = $InteractableMultimeter
@onready var display_label: Label3D = $InteractableMultimeter/Model/DisplayLabel
@onready var on_off_button: PokeButton = $InteractableMultimeter/Model/OnOff_PokeButton
@onready var positive_probe: InteractableObject = $InteractableMultimeterProbePositive
@onready var negative_probe: InteractableObject = $InteractableMultimeterProbeNegative
@onready var positive_cable: Cable = $CablePositive
@onready var negative_cable: Cable = $CableNegative
@onready var resistance_network: ResistanceNetwork = $ResistanceNetwork

var is_powered_on: bool = false
var is_measuring: bool = false
var positive_pin: Pin
var negative_pin: Pin
var measurement_timer: Timer
var measured_resistance: float = 0.0
var target_resistance: float = 0.0

func _ready() -> void:
  on_off_button.pressed.connect(_toggle_power)
  
  multimeter_object.snapped_to_zone.connect(_on_multimeter_snapped_to_zone)
  multimeter_object.unsnapped_from_zone.connect(_on_multimeter_unsnapped_to_zone)
  
  # Connect probe signals
  positive_probe.entered_zone.connect(_on_positive_probe_connected)
  positive_probe.exited_zone.connect(_on_positive_probe_disconnected)
  negative_probe.entered_zone.connect(_on_negative_probe_connected)
  negative_probe.exited_zone.connect(_on_negative_probe_disconnected)
  
  measurement_timer = Timer.new()
  measurement_timer.wait_time = update_rate
  measurement_timer.timeout.connect(_update_measurement)
  add_child(measurement_timer)
  
  # Initialize cable flow state
  _update_cable_flow()

func _toggle_power() -> void:
  is_powered_on = !is_powered_on

  if is_powered_on:
    _power_on()
  else:
    _power_off()

func _power_on() -> void:
  print("Multimeter powered ON")
  
  measurement_timer.start()
  
  # Initial display
  _update_display("OL")  # Overload/Open circuit
  display_label.visible = true
  
  # Check if probes are already connected
  _check_measurement_state()

func _power_off() -> void:
  print("Multimeter powered OFF")
  
  measurement_timer.stop()
  
  # Clear display
  display_label.visible = false
  
  # Reset measurement state
  if is_measuring:
    is_measuring = false
    measured_resistance = 0.0
    target_resistance = 0.0
    emit_signal("measurement_ended")
  
  _update_cable_flow()

func _update_display(text: String) -> void:
  if display_label:
    display_label.text = text

func _on_multimeter_snapped_to_zone(_zone: SnappingZone) -> void:
  # Hide probes and cables if the multimeter got snapped (to the toolbox atm)
  positive_probe.enabled = false
  negative_probe.enabled = false
  positive_cable.visible = false
  negative_cable.visible = false
  
func _on_multimeter_unsnapped_to_zone() -> void:
  positive_probe.enabled = true
  negative_probe.enabled = true
  positive_cable.visible = true
  negative_cable.visible = true

func _on_positive_probe_connected(zone: SnappingZone) -> void:
  positive_pin = _find_pin(zone)
  _check_measurement_state()

func _on_positive_probe_disconnected(_zone: SnappingZone) -> void:
  positive_pin = null
  _check_measurement_state()

func _on_negative_probe_connected(zone: SnappingZone) -> void:
  negative_pin = _find_pin(zone)
  _check_measurement_state()

func _on_negative_probe_disconnected(_zone: SnappingZone) -> void:
  negative_pin = null
  _check_measurement_state()

func _find_pin(zone: SnappingZone) -> Pin:
  var parent = zone.get_parent()
  if parent && parent is Pin:
    return parent
  
  return null

func _check_measurement_state() -> void:
  if !is_powered_on:
    return
  
  var should_measure = positive_pin && negative_pin && positive_pin != negative_pin
  
  if should_measure && !is_measuring:
    _start_measurement()
  elif should_measure && is_measuring:
    _update_target_resistance()
  elif !should_measure && is_measuring:
    _stop_measurement()
  
  # Always update cable flow when measurement state potentially changes
  _update_cable_flow()

func _start_measurement() -> void:
  if is_measuring:
    return
    
  is_measuring = true
  
  _update_target_resistance()
  _update_cable_flow()
  
  emit_signal("measurement_started")

func _update_target_resistance() -> void:
  if positive_pin && negative_pin && resistance_network:
    target_resistance = resistance_network.get_resistance_between(positive_pin.pin_name, negative_pin.pin_name)
    
    if target_resistance < 0:
      target_resistance = max_resistance * 10  # Simulate open circuit
  else:
    target_resistance = max_resistance * 10  # Open circuit
  
  # Set measured resistance to a value that will step towards target
  if measured_resistance > target_resistance:
    measured_resistance = target_resistance + 200.0
  else:
    measured_resistance = target_resistance - 200.0

func _stop_measurement() -> void:
  if !is_measuring:
    return
  
  is_measuring = false
  
  # Set target to open circuit
  target_resistance = max_resistance * 10
  _update_cable_flow()
  
  emit_signal("measurement_ended")

func _update_measurement() -> void:
  if !is_powered_on:
    return
  
  if is_measuring:
    # Step towards target resistance
    _step_towards_target()
    _update_display(_format_resistance(measured_resistance))
    emit_signal("resistance_measurement_updated", measured_resistance)
    
    # Update flow speed based on current resistance
    _update_cable_flow()
  else:
    # Step towards open circuit when not measuring
    var open_circuit_value = max_resistance * 10
    if abs(measured_resistance - open_circuit_value) > resistance_step_threshold:
      _step_towards_open_circuit()
      _update_display(_format_resistance(measured_resistance))
    else:
      measured_resistance = open_circuit_value
      _update_display("OL")  # Overload/Open circuit
    
    # Update flow even when not measuring (should be disabled)
    _update_cable_flow()

func _step_towards_target() -> void:
  var resistance_difference = target_resistance - measured_resistance
  
  # If we're close enough, snap to target
  if abs(resistance_difference) <= resistance_step_threshold:
    measured_resistance = target_resistance
    return
  
  # Calculate step direction and size
  var step_direction = sign(resistance_difference)
  var step_magnitude = min(abs(resistance_difference), resistance_step_size)
  
  measured_resistance += step_direction * step_magnitude

func _step_towards_open_circuit() -> void:
  var open_circuit_value = max_resistance * 10
  var step_direction = sign(open_circuit_value - measured_resistance)
  var step_magnitude = min(abs(open_circuit_value - measured_resistance), resistance_step_size)
  
  measured_resistance += step_direction * step_magnitude

func _update_cable_flow() -> void:
  if !positive_cable || !negative_cable:
    return
  
  # Enable flow only when powered on and measuring with valid resistance
  var should_show_flow = is_powered_on && is_measuring && measured_resistance < max_resistance
  
  positive_cable.enable_flow = should_show_flow
  negative_cable.enable_flow = should_show_flow
  
  if should_show_flow:
    # Calculate flow speed based on resistance (lower resistance = faster flow)
    var resistance_factor = max_resistance / max(measured_resistance, 1.0)
    var flow_speed = base_flow_speed + (resistance_factor * flow_speed_multiplier)
    flow_speed = clamp(flow_speed, min_flow_speed, max_flow_speed)
    
    # For resistance measurement, flow direction can be consistent
    positive_cable.flow_speed = flow_speed
    negative_cable.flow_speed = flow_speed
  else:
    # Reset flow speed to stop animation
    positive_cable.flow_speed = 0.0
    negative_cable.flow_speed = 0.0

func _format_resistance(resistance: float) -> String:
  # Handle out of range
  if resistance > max_resistance:
    return "OL"  # Overload/Open circuit
  
  var display_resistance = resistance
  var unit = "Ω"
  
  # Convert to kOhm if >= 1000 Ohms
  if resistance >= 1000.0:
    display_resistance = resistance / 1000.0
    unit = "kΩ"
    return "%.2f %s" % [display_resistance, unit]
  else:
    return "%.1f %s" % [display_resistance, unit]
