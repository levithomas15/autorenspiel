extends SceneTree

## Rauchtest ohne Fenster — prueft, dass das Spiel wirklich laeuft.
##
## Aufruf:
##   godot --headless --path . --script res://tools/smoke_test.gd
##
## Startet das Rennen nacheinander mit jedem Fahrzeug, gibt Vollgas und
## meldet danach Position, Tempo und Streckenlage. Jeder Skriptfehler
## erscheint dabei in der Ausgabe. Gedacht als schnelle Kontrolle nach
## Aenderungen an Physik, Strecke oder Fahrzeugdaten.

## Rund zehn Sekunden Spielzeit je Fahrzeug: erst der Countdown, dann fahren.
const FRAMES_PER_CAR := 1500

var _main: Node3D = null
var _index: int = 0
var _frames: int = 0


func _process(_delta: float) -> bool:
	# Im ersten Durchlauf steht der Szenenbaum noch nicht vollstaendig.
	if _main == null:
		_start(0)
		return false

	_frames += 1
	if _frames < FRAMES_PER_CAR:
		return false

	_report()
	if _index < CarData.all().size() - 1:
		_start(_index + 1)
		return false
	print("\nAlle Fahrzeuge ohne Fehler durchlaufen.")
	return true


func _start(index: int) -> void:
	if _main != null:
		_main.queue_free()
	_index = index
	_frames = 0
	_main = Node3D.new()
	_main.set_script(load("res://scripts/main.gd"))
	root.add_child(_main)
	_main.selected_index = index
	_main._start_race()
	print("\n=== %s ===" % CarData.all()[index]["name"])
	print("  Strecke %.0f m, Start bei %v" % [_main._track.total_length,
		_main._car.global_position])
	Input.action_press("throttle")


func _report() -> void:
	var car: Car = _main._car
	print("  nach %.1f s Fahrzeit:" % _main._lap_time)
	print("    Tempo    %.1f km/h in Gang %d bei %.0f U/min"
		% [car.speed_kmh, car.gear, car.rpm])
	print("    Abstand zur Ideallinie %.2f m, neben der Strecke: %s"
		% [_main._track.lateral_distance(car.global_position), _main._off_track])
