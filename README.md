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

## Im Browser spielen

Unter `docs/` liegt ein fertiger Web-Export (Godot fuer WebAssembly). Er
laesst sich ueber GitHub Pages veroeffentlichen:

**Settings → Pages → Source**

- entweder **„GitHub Actions"** — dann uebernimmt `.github/workflows/pages.yml`
  jede weitere Veroeffentlichung automatisch, sobald sich `docs/` aendert
- oder **„Deploy from a branch"** mit Branch `main` und Ordner `/docs` —
  ganz ohne Workflow

Adresse danach: **https://levithomas15.github.io/autorenspiel/**

Das erstmalige Einschalten muss von Hand geschehen; GitHub erlaubt das
Anlegen einer Pages-Seite nur angemeldeten Personen, nicht dem Token eines
Workflows.

Neu bauen laesst sich der Export mit:

```
godot --headless --export-release "Web"
```

Im Browser laeuft das Spiel ueber WebGL2 statt Forward+. SDFGI, SSAO, SSR
und der volumetrische Nebel entfallen dort — auf dem Desktop bleibt alles
wie bisher. Von den 43 MB ist fast alles die Godot-Laufzeit; die Spieldaten
sind 92 KB, weil Modelle, Texturen und Sound erst beim Start berechnet
werden.

## Geraetewahl beim Start

Beim ersten Start fragt das Spiel, womit gespielt wird: **Handy**, **iPad**
oder **MacBook**. Die Wahl bestimmt zweierlei und wird gespeichert; in der
Garage fuehrt `Esc` beziehungsweise der Knopf `GERAET` zurueck zur Auswahl.

| | Handy | iPad | MacBook |
|---|---|---|---|
| Steuerung | Lenkrad und Pedale | Lenkrad und Pedale | Tastatur |
| 3D-Aufloesung | 60 % | 75 % | voll |
| Sonnenschatten | aus | 80 m | 160 m |
| Kulisse am Rand | 35 % | 70 % | voll |

**Lenkrad und Pedale sind stufenlos.** Das Lenkrad wird mit dem Finger
gedreht; sein Drehwinkel ist der Einschlag, und losgelassen laeuft es von
selbst in die Mitte zurueck. Die Pedale reagieren auf den Weg: weiter unten
gedrueckt heisst weiter durchgetreten. Der Balken neben dem Pedal zeigt, wie
weit. Beides laeuft ueber `Input.action_press(aktion, staerke)` in dieselben
Actions wie die Tastatur - `car.gd` unterscheidet die Eingabearten nicht.

Lenken und Gasgeben gleichzeitig funktioniert, weil jeder Finger einzeln
verfolgt wird.

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
| **Prisma R** | Allrad-Prototyp, 500 km/h, dreifache Beschleunigung | **Regenbogen-Verlauf** |

Der **Prisma R** ist der schnellste Wagen im Feld: Höchstgeschwindigkeit
500 km/h, und er beschleunigt dreimal so kräftig wie der bis dahin schnellste
(Aurora EV). Gemessen von 0 auf 100 km/h: **1,41 s gegenüber 4,13 s**.

Möglich macht das die Leistung je Masse — genau die bestimmt die
Beschleunigung. Aurora kommt auf 3400 / 1720 = 1,98, der Prisma auf
8100 / 1180 = 6,86. Damit die Kraft nicht bloß die Räder durchdrehen lässt,
hat er Allradantrieb und über `"grip"` deutlich mehr Reifengriff; dieser
Schlüssel ist neu und wirkt bei jedem Fahrzeug.

Sein Lack kommt aus einem Farbverlauf statt einer einzelnen Farbe. Die
Karosserie wird als Loft gebaut, dessen V-Koordinate von der Front zum Heck
läuft — der Regenbogen legt sich damit von selbst in Fahrtrichtung über den
ganzen Wagen. Auch dafür gibt es keine Bilddatei.

Der rosa Wagen ist eine **eigenständig modellierte Hommage**. Es sind keine
lizenzierten Fahrzeugdaten enthalten. Wer den Markennamen nicht verwenden
möchte, ändert eine Zeile: `PINK_CAR_NAME` in `scripts/car_data.gd`.

## Admin-Panel

Dreimal in die **obere rechte Ecke** tippen (innerhalb von zwei Sekunden)
oeffnet ein verstecktes Panel mit sechs Schaltern:

| Schalter | Wirkung |
|---|---|
| **Autopilot** | Faehrt von allein die Ideallinie, so schnell es die Strecke zulaesst |
| **Dreifache Leistung** | Antriebskraft mal drei — wirkt auch auf den Autopiloten |
| **Mondschwerkraft** | Schwerkraft auf ein Sechstel |
| **Zeitlupe** | Alles laeuft auf 35 Prozent Tempo |
| **Alles im Regenbogenlack** | Jedes Fahrzeug bekommt den Verlaufslack |
| **Voller Grip ueberall** | Neben der Strecke haftet es wie auf Asphalt |

Bedienbar per Finger, Maus und Tastatur (`A`/`D` waehlen, `Enter` umschalten,
`Esc` schliesst).

**Der Autopilot faehrt nachweislich sauber.** Gemessen ueber drei volle Runden
mit dem Prisma R: groesster seitlicher Abstand 2,02 m bei 6,6 m halber
Fahrbahnbreite, **null Bilder neben der Strecke** in 37 240 Bildern,
Rundenzeiten 86,0 / 83,8 / 83,8 s. Er rechnet im festen Physiktakt — in
`_process` haette dieselbe Strecke mal sauber und mal in der Leitplanke
geendet. Als Sicherheitsnetz setzt er zurueck, falls er doch einmal laenger
als anderthalb Sekunden steht oder abseits landet.

Die Logik steckt in `scripts/autopilot.gd`: ein Zielpunkt voraus auf
`Track.curve` fuer die Lenkung, und die Richtungsaenderung zwischen zwei
Punkten voraus fuer das Zieltempo. Eine eigene Ideallinie braucht es nicht.

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
