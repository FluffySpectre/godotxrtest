class_name ResistanceNetwork extends Node

# Define resistance values between pins (in Ohms)
var resistances: Dictionary = {
  "Pin A_Pin B": 4200.0,  # 1 kOhm
  "Pin A_Pin C": 4200.0,  # 1.5 kOhm
  "Pin B_Pin C": 0.2      # Short circuit
}

func get_resistance_between(pin1_name: String, pin2_name: String) -> float:
  var key1 = pin1_name + "_" + pin2_name
  var key2 = pin2_name + "_" + pin1_name
  
  if resistances.has(key1):
    return resistances[key1]
  elif resistances.has(key2):
    return resistances[key2]
  else:
    return -1.0  # No connection
