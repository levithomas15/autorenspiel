# Autorennspiel

Ein Rennspiel für **Godot 4.4** mit vier Fahrzeugen — darunter ein
**911 GT3 RS in Rosa-Metallic**.

Das Besondere am Aufbau: **es gibt keine einzige Modell-, Textur- oder
Audiodatei.** Karosserien, Räder, Strecke, Materialien, Himmel und sogar der
Motorsound werden beim Start in GDScript berechnet. Das Repository besteht
deshalb nur aus Text und lässt sich vollständig lesen und verändern.

## Starten

1. Godot 4.4 (oder neuer) öffnen
2. **Import** → diesen Ordner wählen → **Öffnen**
3. **F5** drücken

Beim ersten Start wird die Strecke erzeugt; das dauert einen Moment.

Ob alles läuft, lässt sich auch ohne Fenster prüfen:

```
godot --headless --path . --script res://tools/smoke_test.gd
```

Das fährt jedes der vier Fahrzeuge kurz mit Vollgas und meldet Tempo, Gang und
Streckenlage — praktisch nach Änderungen an Physik, Strecke oder Fahrzeugdaten.

## Steuerung

| Aktion | Tastatur | Gamepad |
|---|---|---|
| Gas | `W` / `↑` | A / rechter Trigger |
| Bremse, Rückwärts | `S` / `↓` | B / linker Trigger |
| Lenken | `A` `D` / `←` `→` | linker Stick |
| Handbremse | `Leertaste` | X |
| Kamera wechseln | `C` | R1 |
| Scheinwerfer | `L` | — |
| Zurücksetzen | `R` | Y |
| Zurück zur Garage | `Esc` | Back |

In der Garage: `A` / `D` wechselt das Fahrzeug, `Q` / `E` dreht den
Drehteller, `Enter` startet das Zeitfahren.

## Die vier Fahrzeuge

| Fahrzeug | Charakter | Lack |
|---|---|---|
| Hornet GT | Mittelmotor-Coupé, ausgewogen | Orange-Metallic |
| Vanta S | Frontmotor-GT, schwer, viel Drehmoment | Graphit-Schwarz |
| Aurora EV | Allrad-Elektro, sofortiger Schub | Elektrik-Blau |
| **911 GT3 RS Rosa** | Heckmotor, Heckantrieb, großer Heckflügel | **Rosa-Metallic mit Klarlack** |

Der rosa Wagen ist eine **eigenständig modellierte Hommage**. Es sind keine
lizenzierten Fahrzeugdaten enthalten. Wer den Markennamen nicht verwenden
möchte, ändert eine Zeile: `PINK_CAR_NAME` in `scripts/car_data.gd`.

## Aufbau

```
scenes/Main.tscn      Startszene - ein Knoten mit scripts/main.gd
scripts/main.gd       Eingaben, Wechsel zwischen Garage und Rennen, Rundenlogik
scripts/garage.gd     Fahrzeugauswahl auf dem Drehteller
scripts/track.gd      Rundkurs: Kurve, Fahrbahn, Randsteine, Leitplanken, Bäume
scripts/car.gd        Fahrphysik auf Basis von VehicleBody3D
scripts/car_data.gd   Die vier Fahrzeugdefinitionen - hier stellt man alles ein
scripts/car_builder.gd   Karosserie, Verglasung, Aerodynamik, Leuchten
scripts/wheel_builder.gd Reifen, Felgen, Bremsen
scripts/mesh_lib.gd   Geometrie-Grundbausteine (Loft, Quader, Zylinder, Torus)
scripts/materials.gd  Materialien inklusive prozeduraler Rauschtexturen
scripts/world_env.gd  Beleuchtung und Post-Processing
scripts/chase_camera.gd  Vier Kameraperspektiven
scripts/hud.gd        Tacho, Drehzahlbogen, Rundenzeiten
scripts/engine_audio.gd  Motorsound aus Grundton und Harmonischen
tools/smoke_test.gd   Rauchtest ohne Fenster
```

## Eigene Anpassungen

**Ein Auto abstimmen:** alles in `scripts/car_data.gd`. `power`, `mass`,
`top_speed`, `steer_max` und `downforce` verändern das Fahrverhalten,
`paint` und `rim_color` das Aussehen.

**Eine Karosserieform ändern:** die Liste unter `"body"` ist die Silhouette.
Jede Zeile ist ein Querschnitt `[t, halbe Breite, y unten, y oben, Rundung
oben, Rundung unten]`, `t` läuft von 0 (Front) bis 1 (Heck). Größere
Rundungswerte ergeben kantigere Schnitte.

**Eine andere Strecke:** die Radiusformel in `Track._build_curve()`. Solange
der Radius positiv bleibt, kann sich die Strecke nicht selbst schneiden.

**Leistung:** `project.godot` steht bewusst auf hohen Qualitätsstufen
(MSAA 4x, TAA, SDFGI, 8k-Schatten). Auf schwächerer Hardware zuerst
`sdfgi_enabled` in `scripts/world_env.gd` abschalten und `msaa_3d` senken.

## Hinweise zur Umsetzung

- Die Fahrzeuge sitzen unter Last etwas tiefer als im unbelasteten Zustand.
  Das ist gewollt: `VehicleWheel3D`-Knoten markieren den Federbeinpunkt, nicht
  die Radmitte.
- Die prozeduralen Materialien rendern beidseitig (`CULL_DISABLED`). Bei
  diesen Polygonzahlen kostet das praktisch nichts und macht das Ergebnis
  unabhängig von der Wicklungsrichtung der Dreiecke. Wer maximale Leistung
  will, setzt `Mats.TWO_SIDED` auf `false` — falls dann Flächen fehlen, kippt
  zusätzlich `MeshLib.FLIP_WINDING`.
- Die Rundenzählung kommt ohne Trigger-Bereiche aus: `Curve3D.get_closest_offset()`
  liefert den Streckenfortschritt, daraus folgen Zielüberfahrt,
  Abkürzungsschutz und die Erkennung neben der Strecke.
