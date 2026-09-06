extends SceneTree

## Wie lange blockiert der Aufbau? Reine Rechenzeit, ohne Rendern.

var _m: Node3D = null
var _n := 0

func _process(_d: float) -> bool:
	if _m == null:
		var t0 := Time.get_ticks_msec()
		_m = Node3D.new()
		_m.set_script(load("res://scripts/main.gd"))
		root.add_child(_m)
		var t1 := Time.get_ticks_msec()
		print("Garage aufbauen:        %5d ms" % (t1 - t0))

		var t2 := Time.get_ticks_msec()
		_m.selected_index = 0
		_m._start_race()
		var t3 := Time.get_ticks_msec()
		print("Rennen aufbauen:        %5d ms   <-- am Stueck, blockiert alles" % (t3 - t2))

		# Einzelteile des Rennaufbaus
		var t4 := Time.get_ticks_msec()
		var tr := Track.new()
		root.add_child(tr)
		var t5 := Time.get_ticks_msec()
		print("  davon Strecke allein: %5d ms" % (t5 - t4))
		tr.queue_free()

		var t6 := Time.get_ticks_msec()
		var c := Car.create(CarData.all()[0])
		root.add_child(c)
		var t7 := Time.get_ticks_msec()
		print("  davon Fahrzeug:       %5d ms" % (t7 - t6))
		c.queue_free()
		return false
	_n += 1
	return _n > 3
