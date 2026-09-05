# Übergabe — Stand des Projekts

Diese Datei ist für eine neue Claude-Session gedacht (oder für dich selbst in
ein paar Wochen). Sie beschreibt, was existiert, was noch nicht geprüft ist und
wo man zuerst nachschaut, wenn etwas nicht funktioniert.

## Was das Projekt ist

Ein Rennspiel für **Godot 4.4**: Solo-Zeitfahren über 5 Runden, vier Fahrzeuge
zur Auswahl, darunter ein **911 GT3 RS in Rosa-Metallic** (eigenständig
modellierte Hommage, keine lizenzierten Daten).

**Der zentrale Entwurfsentscheid:** Es gibt keine einzige Modell-, Textur- oder
Audiodatei. Karosserien, Räder, Strecke, Materialien, Himmel und Motorsound
werden beim Start in GDScript berechnet. Grund: Die Umgebung, in der das
entstand, hatte keine Asset-Pipeline. Wer das Projekt weiterbaut, sollte diesen
Ansatz kennen — man ändert Formen hier in Zahlenlisten, nicht in einem
3D-Programm.

Repository: `levithomas15/autorenspiel`
Branches: `main` und `claude/godot-racing-game-cars-max3ea` — identischer Stand.

## Status

**Vollständig gebaut und gepusht. Noch nie ausgeführt.**

Godot war in der Bau-Umgebung nicht installiert, ein Testlauf war deshalb
unmöglich. Geprüft wurde stattdessen:

- jede Datei statisch gegen die Godot-4.4-API (Klassen, Properties, Enums)
- alle klassenübergreifenden Aufrufe lösen auf (Prüfskript)
- alle 29 Fahrzeug-Schlüssel in allen vier Definitionen vorhanden
- keine fehlenden `res://`-Pfade, Klammern ausgeglichen, nur Tab-Einrückung

Der erste `F5`-Start ist also der eigentliche Test.

## Erste Schritte in einer neuen Session

Wenn beim Start Fehler auftreten, sind das die wahrscheinlichsten Stellen —
in dieser Reihenfolge prüfen:

1. **Godot-Version.** Alles ist gegen 4.4 geschrieben. Bei 4.2/4.3 können
   einzelne Environment-Properties fehlen (`ssil_*`, `volumetric_fog_*`).
2. **Fahrzeug sinkt ein oder hüpft.** `scripts/car.gd`, `_build_wheels()`:
   `suspension_stiffness`, `suspension_travel`, `wheel_rest_length` und die
   Höhe der Kollisionsboxen in `_build_collision()` hängen zusammen. Der
   `VehicleWheel3D`-Knoten markiert den **Federbeinpunkt**, nicht die Radmitte —
   das Auto sitzt unter Last bewusst tiefer.
3. **Flächen fehlen oder sind schwarz.** Die Materialien rendern beidseitig
   (`Mats.TWO_SIDED`). Falls doch etwas fehlt: `MeshLib.FLIP_WINDING` kippen.
4. **Strecke sieht falsch aus.** `Track.frame_at()` baut das begleitende
   Koordinatensystem. Godot blickt entlang **-Z**; die Basis ist
   `Basis(rechts, oben, -vorne)` mit `rechts = vorne × oben`. Ein Vorzeichen
   falsch, und die Kurvenüberhöhung kippt in die verkehrte Richtung.
5. **Ruckeln.** `project.godot` steht auf hohen Qualitätsstufen. Zuerst
   `sdfgi_enabled = false` in `scripts/world_env.gd`, dann `msaa_3d` senken.

## Dateien

| Datei | Inhalt |
|---|---|
| `scenes/Main.tscn` | Startszene: ein Knoten mit `main.gd`. Bewusst minimal — alles andere wird im Code aufgebaut. |
| `scripts/main.gd` | Eingaben (zur Laufzeit via `InputMap`), Garage ↔ Rennen, Rundenlogik |
| `scripts/car_data.gd` | **Die vier Fahrzeuge. Hier stellt man alles ein.** |
| `scripts/car_builder.gd` | Karosserie, Verglasung, Innenraum, Aerodynamik, Leuchten |
| `scripts/wheel_builder.gd` | Reifen, Felgen, Bremsen |
| `scripts/car.gd` | `VehicleBody3D`, Gänge, Lenkung, Abtrieb, Grip |
| `scripts/track.gd` | Kurve, Fahrbahn, Randsteine, Böschung, Leitplanken, Bäume |
| `scripts/mesh_lib.gd` | Geometrie-Grundbausteine — **alles andere baut darauf auf** |
| `scripts/materials.gd` | Materialien inkl. prozeduraler Rauschtexturen |
| `scripts/world_env.gd` | Licht, SDFGI, SSR, Glow, Nebel |
| `scripts/chase_camera.gd` | Vier Perspektiven |
| `scripts/hud.gd` | Tacho, Drehzahlbogen, Rundenzeiten |
| `scripts/garage.gd` | Auswahl auf dem Drehteller |
| `scripts/engine_audio.gd` | Motorsound aus Grundton + Harmonischen |

## Bewusst nicht gebaut

- **Keine KI-Gegner.** Auf Wunsch des Nutzers Solo-Zeitfahren, damit die Zeit
  in Optik und Fahrgefühl geht. Nachrüstbar über die vorhandene
  `Track.curve` als Ideallinie — der Aufbau muss dafür nicht geändert werden.
- Kein Speichern von Bestzeiten über das Spielende hinaus.
- Kein Menü für Grafikeinstellungen.
