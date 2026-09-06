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

**Gebaut und erstmals ausgeführt** — mit Godot 4.4.1 headless, alle vier
Fahrzeuge fahren.

Beim ersten echten Start fielen drei Parse-Fehler auf, die das Spiel komplett
am Laden hinderten (`car.gd:82`, `garage.gd:126`, `track.gd:255`): Schleifen
über Array-Literale wie `for s in [-1.0, 1.0]` liefern eine `Variant`-Variable,
und aus einer `Variant` kann `:=` keinen Typ ableiten. Behoben durch explizite
Schleifentypen (`for s: float in [...]`, `for axle: String in [...]`).

Danach läuft es durch: Strecke 2287 m, Garage und Rennen bauen sich fehlerfrei
auf, alle vier Autos beschleunigen und bleiben auf der Fahrbahn.

Inzwischen auch **mit Bild geprüft** — unter Xvfb, sowohl im
Kompatibilitätsmodus als auch in Forward+ über den Software-Vulkan lavapipe.
Karosserien, Räder, Strecke, Randsteine, Leitplanken, Bäume, Himmel und HUD
rendern. Dabei fielen drei HUD-Fehler auf (siehe unten), die behoben sind.

**Einschränkung:** gerendert wurde per Software-Rasterizer. Für Geometrie und
Layout reicht das, für die Bildwirkung nicht — SDFGI konvergiert dabei nicht,
TAA und SSR fehlen im Kompatibilitätsmodus. Wie Lack, Spiegelungen und
Beleuchtung wirklich aussehen, beurteilt erst dein `F5` auf dem Mac.

### Rauchtest

```
godot --headless --path . --script res://tools/smoke_test.gd
```

Fährt jedes Fahrzeug rund zehn Sekunden mit Vollgas und meldet Tempo, Gang und
Streckenlage. Skriptfehler tauchen dabei in der Ausgabe auf. Lohnt sich nach
jeder Änderung an Physik, Strecke oder Fahrzeugdaten — es ist deutlich
schneller als das Spiel von Hand zu starten.

### Behobene HUD-Fehler

Bei einem `Control` ist `position` die Lage im Elternraum, **nicht** der
Versatz zum Anker. `set_anchors_preset(...)` gefolgt von
`position = Vector2(-400, 120)` setzte die Meldung deshalb wörtlich auf
x = −400. Folgen, alle drei behoben in `scripts/hud.gd`:

- Countdown, Rundenzeiten und „Bestzeit" standen halb außerhalb des linken
  Bildrands — praktisch unsichtbar.
- Die Steuerungshinweise lagen bei y = −56, also über dem oberen Bildrand.
- Der Zeitblock oben links überlappte sich: ein `Label` wächst auf seine
  Mindesthöhe, die Zeilenabstände waren für Schriftgröße 38 zu eng.

Anker und Offsets werden jetzt getrennt gesetzt (`PRESET_TOP_WIDE` bzw.
`PRESET_BOTTOM_WIDE` plus `offset_*`). Das ist unabhängig davon, wann das
Elternelement seine Größe bekommt.

### Offene Punkte fürs Auge

Zwei Dinge sind aufgefallen, aber bewusst **nicht** geändert — sie sind
Geschmacksfragen und brauchen ein Urteil auf echter Hardware:

1. **Das Start-Ziel-Feld ist eine große weiße Fläche.** `_build_road()` gibt
   den ersten beiden Schritten (`on_grid: i < 2`, bei `STEP = 3.0` also 6 m)
   ein Karo, dessen Spalten sich nach dem Spaltenindex abwechseln. Zwei dieser
   Spalten sind 3,5 m breit — daraus werden zwei breite weiße Bahnen statt
   eines Karomusters. Ein feineres Muster bräuchte eigene Spalten für den
   Startbereich.

2. **Die Normal-Map des Asphalts erzeugt Streifen.** Ein Testrender ohne sie
   ergab eine sauber graue Fahrbahn. Ursache sind die UVs in `_quad()`: `u`
   läuft je Streifen fest von 0 bis 1, egal ob der Streifen 0,2 m oder 3,5 m
   breit ist. Die Texeldichte ist damit von Streifen zu Streifen völlig
   verschieden und die Textur auf den breiten Bahnen stark gedehnt. Sauber
   wäre, `u` aus der tatsächlichen Breite zu bilden — das ändert `_quad()`
   und alle Aufrufer.

Zusätzlich begrenzt `Mats.noise_texture()` jetzt optional den Wertebereich
(`low`/`high`). Godot **multipliziert** `roughness` mit der Texturhelligkeit;
ohne Untergrenze fiel die Rauheit des Asphalts stellenweise auf 0, die Fläche
wurde dort spiegelglatt. Im Software-Render war davon nichts zu sehen — mit
aktivem SSR auf echter Hardware sehr wahrscheinlich schon.

### Beobachtung zur Abstimmung

Aus dem Stand über 6,8 Sekunden Vollgas erreichen die drei Verbrenner nur
64–68 km/h, der allradgetriebene Aurora EV dagegen 133 km/h. Das ist kein
Fehler — die Heck- und Frontantriebe verlieren Traktion, während der Allradler
seine Leistung auf vier Räder verteilt. Der Unterschied ist aber größer als er
sein sollte; für einen GT3 RS ist das zu zäh. Ansatzpunkte, falls du das
angehen willst: `power` und `mass` in `scripts/car_data.gd`, sowie
`_base_friction` und der Drehmomentverlauf in `scripts/car.gd:182`.

## Erste Schritte in einer neuen Session

Wenn beim Start Fehler auftreten, sind das die wahrscheinlichsten Stellen —
in dieser Reihenfolge prüfen:

1. **Godot-Version.** Alles ist gegen 4.4 geschrieben und mit 4.4.1 getestet.
   Bei 4.2/4.3 können einzelne Environment-Properties fehlen (`ssil_*`,
   `volumetric_fog_*`).
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
| `scripts/cheats.gd` | Schalter des Admin-Panels, statisch |
| `scripts/autopilot.gd` | Selbstfahren entlang `Track.curve` |
| `scripts/admin_panel.gd` | Das Panel, drei Tipps in die obere rechte Ecke |
| `scripts/device.gd` | Geraeteprofil samt Qualitaetsstufen |
| `scripts/device_select.gd` | Auswahlbildschirm beim Start |
| `scripts/touch_controls.gd` | Lenkrad und Pedale |
| `tools/smoke_test.gd` | Rauchtest ohne Fenster (siehe oben) |

**Neue Schlüssel in `car_data.gd`:** `"grip"` (Reifengriff, Vorgabe 3.2) und
`"paint_style": "rainbow"` für den Verlaufslack. Beide sind optional — Fahrzeuge
ohne sie verhalten sich unverändert.

## Bewusst nicht gebaut

- **Keine KI-Gegner.** Auf Wunsch des Nutzers Solo-Zeitfahren, damit die Zeit
  in Optik und Fahrgefühl geht. Nachrüstbar über die vorhandene
  `Track.curve` als Ideallinie — der Aufbau muss dafür nicht geändert werden.
- Kein Speichern von Bestzeiten über das Spielende hinaus.
- Kein Menü für Grafikeinstellungen.
