class_name Autopilot
extends RefCounted

## Faehrt das Fahrzeug selbst - und zwar so, dass es nicht einschlaegt.
##
## Zwei Regelkreise:
##
## 1. **Lenken.** Ein Zielpunkt liegt ein Stueck voraus auf der Streckenkurve.
##    Je schneller, desto weiter voraus, sonst faengt das Auto zu spaet an
##    einzulenken. Dazu eine Ruecklage-Korrektur, die den Zielpunkt zur
##    Streckenmitte zieht, wenn das Auto seitlich abgekommen ist.
##
## 2. **Tempo.** Aus der Richtungsaenderung zwischen zwei Punkten voraus folgt,
##    wie eng es gleich wird. Je enger, desto niedriger das Zieltempo - und es
##    wird rechtzeitig davor gebremst, nicht erst in der Kurve.
##
## `Track.curve` liefert beides, deshalb braucht der Autopilot keine eigene
## Ideallinie und keine zusaetzlichen Daten in der Strecke.

## Wie weit vorausgeschaut wird: Grundwert plus Anteil des Tempos.
const LOOK_BASE := 9.0
const LOOK_PER_SPEED := 0.60
const LOOK_MIN := 9.0
const LOOK_MAX := 55.0

## Zieltempo in Metern je Sekunde, von weiter Kurve bis Haarnadel.
const SPEED_STRAIGHT := 46.0
const SPEED_TIGHT := 11.0

## Ab welcher Richtungsaenderung (Bogenmass) als "eng" gilt. Niedriger heisst:
## frueher als Kurve erkannt und frueher gebremst.
const BEND_TIGHT := 0.38

const STEER_GAIN := 3.4
const RECENTER_GAIN := 1.15

## Je weiter das Auto von der Mitte weg ist, desto staerker wird zusaetzlich
## das Tempo gedrosselt - wer schon weit aussen ist, faehrt sich sonst fest.
const LATERAL_BRAKE := 0.55


## Liefert (Gas, Bremse, Lenkung) - Lenkung positiv heisst nach links,
## genau wie die Actions es liefern wuerden.
static func drive(car: Car, track: Track) -> Vector3:
	if car == null or track == null:
		return Vector3.ZERO

	var pos := car.global_position
	var offset: float = float(track.progress_at(pos))
	var speed: float = maxf(car.forward_speed, 0.0)
	var look: float = clampf(LOOK_BASE + speed * LOOK_PER_SPEED, LOOK_MIN, LOOK_MAX)

	var near_frame := track.frame_at(offset + look)
	var far_frame := track.frame_at(offset + look * 2.0)

	# Seitlicher Versatz zur Streckenmitte, mit Vorzeichen.
	var here := track.frame_at(offset)
	var lateral: float = here.basis.x.dot(pos - here.origin)

	# Der Zielpunkt wandert gegen den Versatz - das holt das Auto zurueck auf
	# die Mitte, statt es parallel zur Strecke weiterlaufen zu lassen.
	var aim: Vector3 = near_frame.origin - near_frame.basis.x \
		* clampf(lateral * RECENTER_GAIN, -Track.HALF_WIDTH, Track.HALF_WIDTH)

	# --- Lenken ---------------------------------------------------------------
	var local: Vector3 = car.global_transform.affine_inverse() * aim
	# local.x > 0 heisst: das Ziel liegt rechts. Nach rechts lenken ist ein
	# negativer Wert, deshalb das Minus.
	var ahead: float = maxf(absf(local.z), 1.0)
	var steer: float = clampf(-local.x / ahead * STEER_GAIN, -1.0, 1.0)

	# --- Tempo ----------------------------------------------------------------
	var to_near: Vector3 = (near_frame.origin - pos)
	var to_far: Vector3 = (far_frame.origin - near_frame.origin)
	to_near.y = 0.0
	to_far.y = 0.0
	var bend: float = 0.0
	if to_near.length_squared() > 0.01 and to_far.length_squared() > 0.01:
		bend = to_near.normalized().angle_to(to_far.normalized())

	var target_speed: float = lerpf(SPEED_STRAIGHT, SPEED_TIGHT,
		clampf(bend / BEND_TIGHT, 0.0, 1.0))
	# In engen Kurven zusaetzlich vom Lenkeinschlag abhaengig bremsen.
	target_speed *= lerpf(1.0, 0.55, absf(steer))
	# Und noch einmal, je weiter das Auto von der Mitte abgekommen ist.
	target_speed *= lerpf(1.0, LATERAL_BRAKE,
		clampf(absf(lateral) / Track.HALF_WIDTH, 0.0, 1.0))

	var throttle: float = 0.0
	var brake: float = 0.0
	if speed < target_speed:
		throttle = clampf((target_speed - speed) * 0.5, 0.15, 1.0)
	else:
		brake = clampf((speed - target_speed) * 0.5, 0.0, 1.0)

	# Steht das Auto quer oder rueckwaerts, erst wieder Fahrt aufnehmen.
	if car.forward_speed < 1.0:
		throttle = 1.0
		brake = 0.0

	return Vector3(throttle, brake, steer)
