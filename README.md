# Telemet für EdgeTX



## Worum es geht

Telemet ist ein Widget für EdgeTx, das eine Vielzahl von Telemetriewerten darstellen kann. Der Schwerpunkt liegt auf Werten aus dem Frsky D16 Protokoll und den von Frsky angebotenen Sensoren, openXsensor und BlHeli_32 Reglern. 
In seiner aktuellen Version ist es auf Farbbildschirme mit einer Auflösung von 480x272 Pixeln optimiert. Fernsteuerungen wie Radiomaster TX16S, Jumper TX16 etc sind die passende Hardware.

Wegen der enthaltenen Touch Funktionen ist das Widget nicht für OpenTx geeignet.

Bild Beispiel

Für den Schiffs und Funktionsmodellbau sind Touchbuttons eingeführt worden, die über den Telemetriekanal des D16 Protokolls bidirektional mit dem Modell kommunizieren können. Dies kommt in meinem ESP32 basieren Übertragungssystem zum Einsatz, siehe XXXXX LINK einfügen. Denkbar ist aber auch ein Projekt, das am S.Port eines Frsky Empfängers angeschlossen wird.

-----------------------------------------------------------------------------------------------------------------------------

## Historie
Begonnen hat das der User johfla siehe 
https://fpv-community.de/threads/lua-scripts-zum-testen.47985/page-34

Inzwischen sind von mir einige Änderungen dazu gekommen. 
Die wichtigste Neuerung ist, dass die Konfiguration in einem separaten File statt findet. Das macht die Wartung einfacher.
Zu erwähnen sei auch, dass Touchbuttons eine Funkübertrag ?????????????????


Full screen 

-----------------------------------------------------------------------------------------------------------------------------

## Installation

Auf der SD Karte im Ordner Widget ist ein Unterordner WIDGETS\Telemet\
anzulegen und die Dateien main.lua und config.lua sowie der Ordner Bilder einzufügen

Lege ein Modell mit dem Namen Screens an und füge eine Seite mit dem Layout Vollbild ein.
Hier wird das Widget Telemetrie hinzugefügt. 

Folgende Optionen stehen zur Auswahl:
transparent Hintergrund weiß oder transparent
Textfarbe Farbe aller Texte und Bezeichnungen
Wertfarbe Farbe aller Messwerte
Rahmenfarbe Farbe aller Umrahmungen

Die Optionen Flight mode, Sliders und Trimms sollten ausgeschaltet sein. 
Die Top Bar kann gerne an sein, dann lässt sich der Vollbildmodus besser erkennen. Auf Seite 1 sollten pro Spalte nicht mehr als drei Widgets konfiguriert sein, sonst wird es mit der Top Bar eng.

Beim Setup des Widgets empfehle ich für den Beginn bei den Voreinstellungen zu bleiben.
Alle weiteren Einstellungen des Modells sind nicht relevant.

Das Widget zeigt nun schon Werte an, da das Modell mit dem Demo Mode konfiguriert ist.
Drücke lange auf den Bildschirm und schalte um auf Fullscreen.
Jetzt können mit den Tasten PAGE> und PAGE< oder durch Wischen mehrere Beispielseiten mit den wichtigsten Widgets angesehen werden.
Durch einen langen Tastendruck auf die Taste RTN wird das Widget wieder klein und kehrt auf die erste Seite zurück.


-----------------------------------------------------------------------------------------------------------------------------
## Konfiguration

Für eigene Modelle kann das Widget über die Datei config.lua angepasst werden.
Öffne die Datei mit einem Texeditor wie dem Editor, den Windows mitbringt, oder besser z.B. mit Notepad++

Hinweis: Alle Anführungszeichen " sind Bestandteil des Programmes und dürfen weder hinzugefügt, noch entfert werden.

Die modellspezifischen Konfugurationen sind in einer Struktur angelegt, deren erste Zeile so beginnt: 

`elseif modelName == "Modellname"  then`

Dann folgen zwei Zeilen, die den Akku und die Widgetdarstellung beschreiben.

Um ein Widget für ein neues Modell zu konfigurieren, kopiere einfach den folgenden Text vor eine elseif - Zeile:

```
elseif modelName == "Modellname" then
	akku = {v_field="a1", celTxt="3s", capa=1300, cells=1, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
	widgetDefinition = {{"rssi2","battery1"},{"armed","timer1","timer2"}, {"altT","vspeed","clock"}}
```

Ersetze den Text innerhalb der Anführungszeichen mit Deinem Modellnamen. Die Schreibweise muss exakt dem entsprechen, wie es in EdgeTx angelegt wurde.

----

#### Beschreibung des verwendten Akkus

Ein Widget, das den Akkuzustand anzeigt und warnt, wenn dieser leer wird sollte immer dabei sein. Ebenso sollte man die Feldstärke RSSI immer sichtbar haben.

Die Widgets battery und battery1 greifen auf die Anaben der Zeile zurück die mit "Akku =" beginnt. 
Eingestellt wird das so:



|Wert|Beschreibung|
|----|----|
|v_field="a1"|Telemetriewert der die Spannung des Modellakkus wiedergibt. Sehe bitte nach, was die Sensorsuche gefunden hat und was Sinn macht. !! Beispiele|
|celTxt="3s"|Kurzer Text der den Akku beschreibt.|
|capa=1300|	Kapazität des Akkus in mAh|
|cells=3|Teiler für die Anzahl der Zellen. Für cells=3 wird bei einer Akkuspannung von 11,1V die durchschnittliche Zellenspannung von 7,2V angezeigt und angesagt. Mit cells=1 wird die Gesamtspannung ausgegeben. Wie man das mag ist reine Geschmacksache. Ich persönlich kann mit der Zellenspannung mehr anfangen.|
|MIN_V=3.5|	Der Wert wirkt sich ausschließlich auf den Spannungsbalken aus und muss entweder pro Zelle oder für den ganzen Akku gereichnet sei. Siehe cells.|
|MAX_V=4.0|	Wie MIN_V |
|WARN_V=3.54|	Wird diese Spannung erreicht, list das Widget die Spannung alle 10 Sekunden vor.|

Die Spannung aus v_field wird mit einem Script gemittelt um kurzzeitige Spannungseinbrüche beim Gasgeben auszugleichen. Der Wert wird, wie oben beschrieben duch die Anzahl der Zellen (cells= ) geteilt und über die Widgets battery und battery1 angezeigt. Der Wert wird darüberhinaus als neuer Sensor "Vcel" zur Verfügung gestellt.

Für neue Modelle: Widget starten und Sensorsuche erneut ausführen, es wird der Sensor "Vcel" gefunden.

----

#### Anzahl Spalten und Zeilen:

Die Anzahl der Parameter in den inneren geschweiften Klammern gibt die Anzahl der Werte pro Spalte vor:

Zwei Werte pro Spalte:
`{"rssi2","battery1"}`

Drei Werte pro Spalte:
`{"armed","timer1","timer2"}`

Vier Werte pro Spalte:
`{"altT","vspeed","clock","rpm"}`
etc.

Die Menge dieser Blöcke innerhalb der äußersten {} bestimmt die Anzahl der Spalten.

----

#### Anzahl Seiten:

Möchte man mehr als eine Seite haben ist das mit dem Parameter pages festzulegen:

`pages = 3`

Das Konstrukt für z.B. drei Seiten sieht so aus:

```
pages = 3
if page == 1 then
	widgetDefinition = {...}
elseif  page == 2 then
	widgetDefinition = {...}
elseif  page == 3 then
	widgetDefinition = {...}				
end
```

----

#### Optionale Parameter:

**demoModeOn = 1**

Schaltet den Demo Modus an. Es werden Beispielwerte statt tatsächlichen Meßwerten angezeigt. Wird der Parameter weg gelassen, oder der Wert auf 0 gesetzt werden echte Werte angezeigt - vorausgesetzt die entsprechenden Sensoren sind angeschlossen.

----

**sendEvents = 0**

Touch und Tastenevents können an den Empfänger über den Telemetriekanal des S.Port (FrSky D16 Telemetrie) übertragen werden. 1=AN, 0=AUS. Details im Kapitel Touch Buttons

----

**stick_switch = 0** 
 
Im rechten Knüppel meiner Fernsteuerung ist ein Zweistufentaster, ähnlich wie im Fotoapparat eingebaut. Den nutze ich zur Ansage von Telemetriewerten.

Angeschlossen ist der Schalter an dem freien Steckplatz auf der Platine meiner TX16S mit der Bezeichnung EX2. In den Sendereinstellungen muss EX2 noch als Poti (mit oder ohne Rast) aktiviert werden. Nach Kalibirierung ist der Wert von EX2 unbetätigt bei 0%, auf Stufe 1 gedrückt bei +100% und auf Stufe 2 gedrückt bei -100%.


Folgende Ansagen können mit dem Taster ausgelöst werden:

|Druck|Ansage|
|----|----|
|kurz, 1. Stufe:|Vbatt|
|kurz, 2. Stufe:|Timer1|
|lang, 1. Stufe:|konfigurierbar|
|lang, 2. Stufe:|Timer2|

	
-----------------------------------------------------------------------------------------------------------------------------
## Widgets

Alle Widgets funktionieren mit 3 und 4 Spalten. Die Anzahl der Widgets die übereinander passen hängt auch davon ab, ob die Infozeile genutzt wird. Im Fullscreen wird die Infozeile überschrieben, es steht also mehr Platz zur Verfügung.
Manche Widgets stehen für unterschiedliche Höhen zur Verfügung.
Das Wechseln zwischen Seiten funktioniert nur im Fullscreen. Das bedeutet, dass die Infozeile nur auf der ersten Seite zur Verfügung steht. 

----

**Werte ohne externe Sensoren**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----
|RSSI|rssi|Feldstärke ohne Grafik|5|4|	
|RSSI|rssi1|Feldstärke mit Grafik|3|3|
|RSSI|rssi2|Feldstärke mit Grafik|2|2|	
|Battery|battery|Akkuspannung variable Quelle|1|1|
|Battery|battery1|Akkuspannung variable Quelle|2|2|
|RxBat|rxbat|Empfängerspannung|5|4|
|Timer1|timer1|Flugzeit|5|4|
|Timer2|timer2|Motorlaufzeit|5|4|
|clock|clock|Uhrzeit und Datum aus Echtzeituhr|5|4|
|Armed/Disarmed|armed|Motorschutzschalter SF|4|3|
|Flightmode|fm, fm1|Flugmodus (ungetestet)|5|4|

---
**Stromsensoren FAS40, FAS100**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----
|Voltage fas|vfas|Frsky FAS40 FAS100|5|4|
|Current fas|curr|Frsky FAS40 FAS100|5|4|
|Fuel|fuel|Welcher Sensor ist das? Auch FAS? (ungetestet)|5|4|

---
**Drehzahlsensor**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----
|RPM|rpm |Frsky RPM Sensor|5|4
|Temp|Grad|Luft und Wassertemperatur mit Tmp1 und Tmp2|5|4

---
**Vario**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----
|Alt|alt|Aktuelle Höhe und Maximalwert|5|4|
|AltT |altT|Aktuelle Höhe und Maximalwert incl. Signalton und Ansage bei +/- 10m, sofern wenn Schalter SG in der mitterlen, oder oberen Position ist|5|4|
|Vertical Speed|vspeed|Steig- Sinkgeschwindigkeit|5|4|


---
**GPS**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----			 
|Heading|hdg|Flugrichtung|? | ?|
|Distance-OpenTx|dist| ??  |
|Distance calculated|dist1|Entfernung ??|5|4|
|GPS Koordinaten|3/4 Widget|	|	
|Speed |speed| ??  |5|4|

---
**FrSky Regler und BlHeli_32**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----
|Esc Current|EscA| Strom in A|5|4|
|Esc Capacity|EscC|Verbrauchte Kapazität in mAh|5|4|
|Esc RPM|EscR|Drehzahl in 1/min|5|4|
|Esc Temperature|EscT|Reglertemperartur in Celcius|5|4|

---
**Hilfe für Programmentwicklung**

|Name|Wert Config|Beschreibung|Widgets pro Spalte|Widgets mit Infozeile|
|---------------|---------------|--------------------|-----------|----
|Debug|debug0 debug1| Fenster zum Debuggen von 2 Werten. debug0 klein oben, debug1 groß unten|5|4|


-- Button mit Text	Bt01Widget // !! Varianten von 01 bis 09 vorstellbar
-- Button mit Bild	Bt10Widget // !! Varianten von 10 bis ?? vorstellbar



-----------------------------------------------------------------------------------------------------------------------------
### Touch Buttons

dbd
	
### Touch Events

dbd
	
### Key Events

dbd

### Übermittlung an Empfänger

dbd
	
### Balken am Button beschreiben

dbd


-----------------------------------------------------------------------------------------------------------------------------
## Inkscape erstellen von Buttons

dbd

-----------------------------------------------------------------------------------------------------------------------------
## Changelog
Wichtig !! Änderungen die die Config betreffen auflisten
!! Versonierung einfügen VV.uu		// 



