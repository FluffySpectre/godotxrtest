class_name MultimeterController extends Node3D

# Signals
signal measurement_started
signal measurement_ended
signal voltage_measurement_updated(voltage: float)

@export var update_rate: float = 0.25 # Measuring rate
@export var max_voltage: float = 1000.0 # Maximum allowed voltage to measure
@export var voltage_step_size: float = 1.5  # Volts per update step
@export var voltage_step_threshold: float = 0.1  # Minimum difference to continue stepping

# References
@onready var display_label: Label3D = $InteractableMultimeter/Model/DisplayLabel
@onready var on_off_button: PokeButton = $InteractableMultimeter/Model/OnOff_PokeButton
@onready var positive_probe: InteractableObject = $InteractableMultimeterProbePositive
@onready var negative_probe: InteractableObject = $InteractableMultimeterProbeNegative

var is_powered_on: bool = false
var is_measuring: bool = false
var positive_power_source: PowerSource
var negative_power_source: PowerSource
var measurement_timer: Timer
var measured_voltage: float = 0.0
var target_voltage: float = 0.0

func _ready() -> void:
  on_off_button.pressed.connect(_toggle_power)
  
  # Connect probe signals
  positive_probe.entered_zone.connect(_on_positive_probe_connected)
  positive_probe.exited_zone.connect(_on_positive_probe_disconnected)
  negative_probe.entered_zone.connect(_on_negative_probe_connected)
  negative_probe.exited_zone.connect(_on_negative_probe_disconnected)
  
  measurement_timer = Timer.new()
  measurement_timer.wait_time = update_rate
  measurement_timer.timeout.connect(_update_measurement)
  add_child(measurement_timer)

func _process(delta: float) -> void:
  pass

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
  _update_display("0.00 V")
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
    measured_voltage = 0.0
    target_voltage = 0.0
    emit_signal("measurement_ended")

func _update_display(text: String) -> void:
  if display_label:
    display_label.text = text

func _on_positive_probe_connected(zone: SnappingZone) -> void:
  positive_power_source = _find_power_source(zone)
  _check_measurement_state()

func _on_positive_probe_disconnected(zone: SnappingZone) -> void:
  positive_power_source = null
  _check_measurement_state()

func _on_negative_probe_connected(zone: SnappingZone) -> void:
  negative_power_source = _find_power_source(zone)
  _check_measurement_state()

func _on_negative_probe_disconnected(zone: SnappingZone) -> void:
  negative_power_source = null
  _check_measurement_state()

func _find_power_source(zone: SnappingZone) -> PowerSource:
  var parent = zone.get_parent()
  if parent && parent is PowerSource:
    return parent
  
  return null

func _check_measurement_state() -> void:
  if !is_powered_on:
    return
  
  var should_measure = positive_power_source && negative_power_source
  
  if should_measure && !is_measuring:
    _start_measurement()
  elif should_measure && is_measuring:
    _update_target_voltage()
  elif !should_measure && is_measuring:
    _stop_measurement()

func _start_measurement() -> void:
  if is_measuring:
    return
    
  is_measuring = true
  
  _update_target_voltage()
  
  emit_signal("measurement_started")

func _update_target_voltage() -> void:
  if positive_power_source && negative_power_source:
    target_voltage = positive_power_source.voltage - negative_power_source.voltage
  else:
    target_voltage = 0.0
  
  # Set measured voltage to a value near the target voltage
  if measured_voltage > target_voltage:
    measured_voltage = target_voltage + 3.0
  else:
    measured_voltage = target_voltage - 3.0

func _stop_measurement() -> void:
  if !is_measuring:
    return
  
  is_measuring = false
  
  _update_target_voltage()
  
  emit_signal("measurement_ended")

func _update_measurement() -> void:
  if !is_powered_on:
    return
  
  if is_measuring:
    # Step towards target voltage
    _step_towards_target()
    _update_display(_format_voltage(measured_voltage))
    emit_signal("voltage_measurement_updated", measured_voltage)
  else:
    # Step towards zero when not measuring
    if abs(measured_voltage) > voltage_step_threshold:
      _step_towards_zero()
      _update_display(_format_voltage(measured_voltage))
    else:
      measured_voltage = 0.0
      _update_display("0.00 V")

func _step_towards_target() -> void:
  var voltage_difference = target_voltage - measured_voltage
  
  # If were close enough, snap to target
  if abs(voltage_difference) <= voltage_step_threshold:
    measured_voltage = target_voltage
    return
  
  # Calculate step direction and size
  var step_direction = sign(voltage_difference)
  var step_magnitude = min(abs(voltage_difference), voltage_step_size)
  
  measured_voltage += step_direction * step_magnitude

func _step_towards_zero() -> void:
  var step_direction = -sign(measured_voltage)
  var step_magnitude = min(abs(measured_voltage), voltage_step_size)
  
  measured_voltage += step_direction * step_magnitude
  
  # Snap to zero if very close
  if abs(measured_voltage) <= voltage_step_threshold:
    measured_voltage = 0.0

func _format_voltage(voltage: float) -> String:
  var abs_voltage = abs(voltage)
  var unit = "V"
  var display_voltage = voltage
  
  # TODO: Fix font sizing first
  #if abs_voltage < 0.001:
    #display_voltage = voltage * 1000000.0
    #unit = "µV"
  #elif abs_voltage < 1.0:
    #display_voltage = voltage * 1000.0
    #unit = "mV"
  
  # Handle out of range
  if abs(voltage) > max_voltage:
    return "OL"  # Overload
  
  var format_string = "%.2f %s" # 2 decimal places
  return format_string % [display_voltage, unit]
