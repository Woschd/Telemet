
-- ######################################################
-- ## Script by johfla 						           ##
-- ## V 1.0, 2017/01/25                                ##
-- ## Dynamic design via initial values and functions  ##
-- ## Some of the Widgets based on work by Ollicious   ##
-- ## tewaked by Andreas_							   ##
-- ## V21 22.10.2022				   				   ##
-- ######################################################

--[[
Versionen 
V19 Farben und Transparenz konfigurierbar gemacht, Demo Mode in config pro Modell einstellbar
V20 Widgets neu sortiert
V21 Widget Namen angepasst

--]]


--[[
Baustellen: kann man mit Swipen kleiner Seite 1 gehen -> bricht mit Fehler ab?? oder war das nur ein dummer Tastendruck

!! neuer Name: Screens Telemet

Seitenzahl in Battery Widget eintragen

Touch Events nach 1.8 anpassen und testen

read_switch() konfigurierbar machen für User ohne Knüppelschalter und kurz halb Wert ansagen

!! Bilder bei Programmstart laden

!! Voltage Lipo - von der Bezeichnung irgendwie passt das nicht dazu. Es kommt aus dem FrSky Stromsensor

--]]


--Zweite Datei einbinden:
--https://www.corsix.org/content/common-lua-pitfall-loading-code


demoModeOn = 0					-- Demo Modus mit festen Telemetriewerten / 1=ON, 0=OFF kann pro Modell in config überschrieben werden
sendEvents = 0					-- Schickt Touch und Tastenevents über Telemetriekanal an Empfänger (nur D16) / 1=ON, 0=OFF kann pro Modell in config überschrieben werden
Trim5_GV1  = 0					-- Trim5 wird glesen und in die golbale Variable GV1 geschrieben

local col_alm = RED				-- standard alarm value color  --!! Konfigurierbar machen, in das Batteriewidget auch einbinden -- verwendet in fuel und flightmode

page = 1						-- in full screen mode, up to 7 pages are possible
pages = 1						-- number of pages available, can be overwritten by config
local gridColum = 0
local gridRow = 0

local imagePath = "/WIDGETS/Telemet/Bilder/" 	-- Pfad zu den Bildern auf der SD-Card  
local bitmaps = {}				-- array for button images
local key_AS = {}				-- arrey for button state, active, slider
local still_pressed = 0

local homeLat = 0     			-- Längengrad der Home Position
local homeLon = 0				-- Breitengrad der Home Position  

local homeSet = 0				-- 1 wenn GPS Ausgangskoordinaten gesetzt sind siehe dist1
local MotorAn = 0				-- 1 wenn scharf geschaltet ist siehe Armed/Disarmed (Switch)

-- Parameter für die Schriftgröße und Korrekturfaktoren der Werte und Einheiten
local modeSize = {sml = SMLSIZE, mid = MIDSIZE, dbl = DBLSIZE}
local modeAlign = {ri = RIGHT, le = LEFT}
local yCorr = {sml = 16, mid = 8,  dbl = 0}
local xCorr = {value = 0.75, value1 = 0.50, center = 7}

local Vbatt=nil					-- Gemittelte Batteriespannung
local Vbatt_tlast				-- time mark 
local Vbatt_tfirst=nil			-- first time a voltage was detected
local Vbatt_talarm=0			-- time of last alarm

local alt_last = 0				-- time mark used in altTalkWidget


--reading the momentary stick switch
local click_state = 0			-- 0 not pressed, 1 half way pressed, 2 fully pressed
local click_state_last = 0
local click_time_last = 0
local click_duration = 0
local click_long = 0
local click_cf_reset = 0



-- das sind die Default Einstellungen, die können in den Modelleinstellungen überschrieben werden
akku = {v_field="VFAS", celTxt="3s", capa=1301, cells= 3, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}


-- ############################# Widget Optionen #################################

local options = {
	{ "transparent", BOOL, 0 },
	{ "Textfarbe", COLOR, DARKGREY }, -- BLACK WHITE LIGHTWHITE YELLOW BLUE DARKBLUE GREY DARKGREY LIGHTGREY RED DARKRED GREEN DARKGREEN LIGHTBROWN DARKBROWN BRIGHTGREEN ORANGE
	{ "Wertfarbe", COLOR, DARKBLUE },
	{ "Hintergrundfarbe", COLOR, WHITE },	
	{ "Rahmenfarbe", COLOR, LIGHTGREY }
}

function create(zone, options)

	--Die vollständige Konfiguration ist in config.lua ausgelagert
	loaded_chunk = assert(loadfile("/WIDGETS/Telemet/config.lua")) 
	loaded_chunk()	
	
	local thisZone  = { zone=zone, options=options }
		col_bak = thisZone.options.Hintergrundfarbe
		col_txt = thisZone.options.Textfarbe
		col_val = thisZone.options.Wertfarbe
		col_frm = thisZone.options.Rahmenfarbe
		widget()
	return thisZone
	
end

function update(thisZone, options)
  thisZone.options = options
  col_bak = thisZone.options.Hintergrundfarbe
  col_txt = thisZone.options.Textfarbe
  col_val = thisZone.options.Wertfarbe
  col_frm = thisZone.options.Rahmenfarbe
end

-- ############################# Werte holen und berechnen #################################

------------------
-- Telemetry ID --
------------------
local function getTelemetryId(name)
	field = getFieldInfo(name)
	if field then
	  return field.id
	else
	  return -1
	end
end

---------------
-- Get Value --
--------------- 
local function getValueOrDefault(value)
	local tmp = getValue(value)
	
	if tmp == nil then
		return 0
	end
	
	return tmp
end

----------------------
-- Get Value Rounded--
---------------------- 
local function round(num, decimal)
    local mult = 10^(decimal or 0)
    return math.floor(num * mult + 0.5) / mult
 end
 
 
---------------------------------------
-- Get battery voltage and filter it --
-- It provdes the new sensor Vcel = battery voltage per cell --
---------------------------------------

local function readBat()
	
	local vr = getValue(akku.v_field) / akku.cells
	if vr and vr>0 then 
		if Vbatt then 								--filter vbatt with a moving average
			local dt=getTime()-Vbatt_tlast
			Vbatt=(Vbatt*500+vr*dt)/(500+dt) 		-- 5 seconds timebase
			setTelemetryValue(0XFFF0, 0, 32, Vbatt*100, 1, 2, "Vcel")
		else
			Vbatt=vr
		end
		Vbatt_tlast=getTime()
		
		if Vbatt_tfirst ==nil then					-- first time a voltage was detected
			Vbatt_tfirst = getTime()
		end
		
		if getTime() - Vbatt_tfirst > 3000 and Vbatt < akku.WARN_V and getTime() - Vbatt_talarm > 1000 then		-- verzögert die erste Spannungsansage um 30 sec. nach Srciptstart
			playNumber(Vbatt*10, 1, PREC1)
			Vbatt_talarm = getTime()																			-- Unterspannungsansage alle 10sec.
		end
		
	else
		Vbatt=nil
	end
end


------------------------------------------------- 
-- Trim5 wird glesen und in die golbale Variable GV1 geschrieben
-- Das kann benutzt werden um z.B. die Prozentzahl einer Zumischung über die Trim5 einstellen zu können.
-- Die Werte gehen von -34 bis +34
-------------------------------------------------

local function Trim5_to_GV1()
	model.setGlobalVariable(0, 0, getValue('trim-t5')/30)
end


-- ############################# Widgets #################################

------------------------------------------------- 
-- RSSI -------------------------- rssi, rssi1 --
-- rssi ohne Bild, rssi1 mit Bild, rssi2 mit Bild und halber Spaltenhöhe
------------------------------------------------- 

local function rssiWidget(xCoord, yCoord, cellHeight, name)

	local myRssi = getValueOrDefault("RSSI")
	local myMinRssi = getValueOrDefault("RSSI-") 
		
	if demoModeOn == 1 then
      myRssi = 75
	  myMinRssi = 41
	end
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "RSSI", modeSize.sml + CUSTOM_COLOR)
	
	if (name == "rssi") then
		xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
		lcd.setColor(CUSTOM_COLOR, col_val)
		lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMinRssi), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	elseif name == "rssi1" then
		xTxt1 = xCoord + cellWide * xCorr.value1; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
		lcd.setColor(CUSTOM_COLOR, col_val)		
		lcd.drawText(xCoord + cellWide - 70, yCoord + 2, round(myMinRssi), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	elseif name == "rssi2" then
		xTxt1 = xCoord + (cellWide * xCorr.value1)-10; yTxt1 = cellHeight + yCorr.dbl+20; yTxt2 = cellHeight + yCorr.sml+20
		lcd.setColor(CUSTOM_COLOR, col_val)		
		lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMinRssi), modeSize.sml + modeAlign.ri+ CUSTOM_COLOR)
	end
	
	lcd.setColor(CUSTOM_COLOR, col_val)			
	lcd.drawText(xTxt1, yTxt1, round(myRssi), modeSize.dbl+ modeAlign.ri + CUSTOM_COLOR) 
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xTxt1, yTxt2, "dB", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
	
	-- Icon RSSI -----
	if (name == "rssi1") or (name == "rssi2") then
		percent = ((math.log(myRssi-28, 10)-1)/(math.log(72, 10)-1))*100
		if myRssi <=37 then rssiIndex = 1
		elseif
			myRssi > 99 then rssiIndex = 11
		else
			rssiIndex = math.floor(percent/10)+2
		end
		
		if rssiName ~= imagePath.."rssi"..rssiIndex..".png" then
			rssiName = imagePath.."rssi"..rssiIndex..".png"
			rssiImage = Bitmap.open(rssiName)
		end
		
		local w, h = Bitmap.getSize(rssiImage)
		if (name == "rssi1") then
			xPic= xCoord + cellWide - w - 2; yPic= yCoord + 5
			else
			xPic= xCoord + cellWide - w - 10; yPic= yCoord + 40
		end
		lcd.drawBitmap(rssiImage, xPic, yPic)
	end
	
end


------------------------------------------------- 
-- Battery ----------------- battery, battery1 --
-------------------------------------------------
-- battery füllt eine ganze Spaltenhöhe, battery1 nur die halbe Höhe
local function batteryWidget(xCoord, yCoord, cellHeight, name)

	local myVoltage = 0
	local myPercent = 0
	
	if Vbatt then 								
		myVoltage = Vbatt
	else
		myVoltage = 0
	end
	
	myPercent = math.floor((myVoltage-akku.MIN_V) * (100/(akku.MAX_V-akku.MIN_V)))
	if myPercent < 0 then
		myPercent = 0
	elseif myPercent > 100 then
		myPercent = 100
	end
	

	if demoModeOn == 1 then
      myPercent = 80
	  akku.celTxt="3s"
	  akku.capa = 1300
	  myVoltage = 14.85
	end
	
		
	if name == "battery" then
		
		xTxt1 = xCoord+(cellWide * 0.5)-50; yTxt1 = cellHeight + 55; xTxt2 = xCoord + (cellWide/2)-25; yTxt2 = cellHeight+90; 		
		
		lcd.setColor(CUSTOM_COLOR, col_txt)
		lcd.drawText(xCoord + 4, yCoord + 2, "Lipo", modeSize.sml + CUSTOM_COLOR)					
		lcd.drawText(xTxt1, yTxt1, akku.celTxt.."-"..akku.capa, modeSize.mid + CUSTOM_COLOR)
		
		lcd.setColor(CUSTOM_COLOR, col_val)		
		lcd.drawText(xTxt2, yTxt2, myPercent.."%", modeSize.dbl + CUSTOM_COLOR)
	else
		
		yTxt1 = cellHeight -10; xTxt2 = xCoord + (cellWide/2)-3; yTxt2 = cellHeight + 20; 	
		
		lcd.setColor(CUSTOM_COLOR, col_txt)
		lcd.drawText(xCoord + 4, yCoord + 2, "Lipo "..akku.celTxt.." "..akku.capa.."mAh", modeSize.sml + CUSTOM_COLOR)
		lcd.drawText(xTxt2, yTxt1 +10, "%", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
		lcd.drawText(xTxt2, yTxt2 +15, "V", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
		
		lcd.setColor(CUSTOM_COLOR, col_val)		
		lcd.drawText(xTxt2, yTxt1, myPercent, modeSize.mid + modeAlign.ri + CUSTOM_COLOR)
		lcd.drawNumber(xTxt2, yTxt2, round(myVoltage,1)*10, PREC1 + modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
	end
	
	-- icon Batterie -----
	if myPercent > 90 then batIndex = 7
		elseif myPercent > 70 then batIndex = 6
		elseif myPercent > 50 then batIndex = 5
		elseif myPercent > 30 then	batIndex = 4
		elseif myPercent > 20 then batIndex = 3
		elseif myPercent >10 then batIndex = 2
		else batIndex = 1
	end
	
	if batName ~= imagePath.."bat"..batIndex..".png" then
		batName = imagePath.."bat"..batIndex..".png"
		batImage = Bitmap.open(batName)
	end
	
	w, h = Bitmap.getSize(batImage)
	
	if name == "battery" then
		xPic=xCoord + (cellWide * 0.5) - (w * 0.5); yPic= yCoord - h*0.5 + cellHeight*0.5
	else
		xPic=xCoord + (cellWide * 0.5) + 15; yPic= yCoord - h*0.5 + cellHeight*0.35 + 5
	end
	
	lcd.drawBitmap(batImage, xPic, yPic)
end


-------------------------------------------------  
-- RxBat ------------------------------- rxbat --
------------------------------------------------- 
local function rxbatWidget(xCoord, yCoord, cellHeight, name)
	local myRxBat = getValueOrDefault("RxBt")
	local myMinRxBat = getValueOrDefault("RxBt-")
				
	if demoModeOn == 1 then
      myRxBat = 5.7
	  myMinRxBat = 4.8
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "RxBat", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "V", modeSize.sml + modeAlign.le + CUSTOM_COLOR)	
	
	lcd.setColor(CUSTOM_COLOR, col_val)
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMinRxBat,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myRxBat,1), modeSize.dbl+ modeAlign.ri + CUSTOM_COLOR) 
end


------------------------------------------------- 
-- Timer1 ------------------------------- timer1 --
------------------------------------------------- 
local function timer1Widget(xCoord, yCoord, cellHeight, name)
	local teleV_tmp = model.getTimer(0) -- Timer 1
	local myTimer = teleV_tmp.value
	
	if demoModeOn == 1 then
      myTimer = 175
	end
	
	local minute = math.floor(myTimer/60)
	local sec = myTimer - (minute*60)
	if sec > 9 then
		valTxt = string.format("%i",minute)..":"..string.format("%i",sec)
	else
		valTxt = string.format("%i",minute)..":0"..string.format("%i",sec)
	end 
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Flugzeit", modeSize.sml + CUSTOM_COLOR) 
	lcd.drawText(xTxt1, yTxt2, "m:s", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xTxt1, yTxt1, valTxt, modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Timer2 ------------------------------- timer2 --
------------------------------------------------- 
local function timer2Widget(xCoord, yCoord, cellHeight, name)
	local teleV_tmp = model.getTimer(1) -- Timer 2
	local myTimer = teleV_tmp.value
	
	if demoModeOn == 1 then
      myTimer = 175
	end
	
	local minute = math.floor(myTimer/60)
	local sec = myTimer - (minute*60)
	if sec > 9 then
		valTxt = string.format("%i",minute)..":"..string.format("%i",sec)
	else
		valTxt = string.format("%i",minute)..":0"..string.format("%i",sec)
	end 
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "Motorlaufzeit", modeSize.sml + CUSTOM_COLOR) 
	lcd.drawText(xTxt1, yTxt2, "m:s", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xTxt1, yTxt1, valTxt, modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- clock ----------------------------------------
-- Uhrzeit und Datum aus Echtzeituhr
-------------------------------------------------
local function whatch(xCoord, yCoord, cellHeight, name)

	local datenow = getDateTime()
	
	local minutes = datenow.min
	if minutes < 10 then
		minutes = "0"..minutes
	end
	
		
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Uhr", modeSize.sml + CUSTOM_COLOR)
	
	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, datenow.day.."."..datenow.mon.."."..datenow.year, modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, datenow.hour..":"..minutes, modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)


end


------------------------------------------------- 
-- Armed/Disarmed (Switch) ------------- armed --
------------------------------------------------- 
local function armedWidget(xCoord, yCoord, cellHeight, name)
	local switchPos = getValueOrDefault("sf")
	if switchPos < 0 then	
		valPng = "stop"
	else
		valPng = "go"
	end
			
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "Motor", modeSize.sml + CUSTOM_COLOR) 
	
	-- Icon Motor -----
	if  motName ~= imagePath..valPng..".png" then
		motName  = imagePath..valPng..".png"
		motImage = Bitmap.open(motName)
	end
	
	local w, h = Bitmap.getSize(motImage)
	xPic= xCoord + (cellWide - w) *0.5; yPic= yCoord + 2
	lcd.drawBitmap(motImage, xPic, yPic)
	
end


------------------------------------------------- 
-- Flightmode ------------------------ fm, fm1 --
------------------------------------------------- 
local function fmWidget(xCoord, yCoord, cellHeight, name)
	local modeDesc = {[0]="Manual", [1]="GPS", [2]="RTH", [3]="ATTI"}
	
	if name == "fm" then --set by Naza V2
		local flm,FM = getFlightMode()	-- FlightMode
		valTxt = FM
	else --set by AnySense
		valTxt = modeDesc[fmode]
	end
	
	if demoModeOn == 1 then
      valTxt = "FlightMode"
	end

	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Mode [SB]", modeSize.sml + CUSTOM_COLOR) 
		
	if valTxt == "CAL" then		-- Kalibrierungsmodus bei Seglern
		xTxt1 = xCoord + cellWide*0.5 - (xCorr.center * string.len(valTxt)); yTxt1 = cellHeight + yCorr.dbl
		lcd.setColor(CUSTOM_COLOR, col_alm)
		Size = modeSize.dbl
	else
		xTxt1 = xCoord + cellWide*0.5 - (xCorr.center * string.len(valTxt)); yTxt1 = cellHeight + yCorr.mid
		lcd.setColor(CUSTOM_COLOR, col_val)
		Size = modeSize.mid
	end
				
	lcd.drawText(xTxt1, yTxt1, valTxt, Size  + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Voltage fas	------------------------  vfas --
------------------------------------------------- 
local function vfasWidget(xCoord, yCoord, cellHeight, name)
	local myVoltage = getValueOrDefault("VFAS") 
	local myMinVoltage = getValueOrDefault("VFAS-")
			
	if demoModeOn == 1 then
      myVoltage = 14.8
	  myMinVoltage = 12.3
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)		
	lcd.drawText(xCoord + 4, yCoord + 2, "Spannung", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "V", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMinVoltage,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myVoltage,2), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR) 
	
end


-------------------------------------------------  
-- Current fas ---------------------------curr --
------------------------------------------------- 
local function currWidget(xCoord, yCoord, cellHeight, name)
	local myCurrent = getValueOrDefault("Curr")
	local myMaxCurrent = getValueOrDefault("Curr+")
				
	if demoModeOn == 1 then
      myCurrent = 12.7
	  myMaxCurrent = 35.8
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Strom", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "A", modeSize.sml + modeAlign.le + CUSTOM_COLOR)	
	
	lcd.setColor(CUSTOM_COLOR, col_val)
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxCurrent,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myCurrent,2), modeSize.dbl+ modeAlign.ri + CUSTOM_COLOR) 

end


-------------------------------------------------  
-- Fuel --------------------------------- fuel --
------------------------------------------------- 
local function fuelWidget(xCoord, yCoord, cellHeight, name)
	local myFuel = getValueOrDefault("Fuel")
	local myFuelID = getTelemetryId("Fuel")
	
	if demoModeOn == 1 then
      myFuel = 800
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "Verbrauch", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "mAh", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
	
	if myFuel > akku.capa * 0.8 then						
		lcd.setColor(CUSTOM_COLOR, col_alm)
	else
		lcd.setColor(CUSTOM_COLOR, col_val)
	end
			 
	lcd.drawText(xTxt1, yTxt1, round(myFuel), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR) 
end


------------------------------------------------- 
-- RPM ----------------------------------- rpm --
-------------------------------------------------
local function rpmWidget(xCoord, yCoord, cellHeight, name)
	local myRpm = getValueOrDefault("RPM")
	local myMaxRpm = getValueOrDefault("RPM+") 
	
	if demoModeOn == 1 then
      myRpm = 2305
	  myMaxRpm = 10200
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "RPM", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "UpM", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxRpm,0), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myRpm,0), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Temp ----------------------------- Grad --
-- Luft und Wassertemperatur mit Tmp1 und Tmp2
-------------------------------------------------
local function TempWidget(xCoord, yCoord, cellHeight, name)
	local myTempL = getValueOrDefault("Tmp1") / 10
	--local myMaxTempL = getValueOrDefault("EscT+") 
	local myTempW = getValueOrDefault("Tmp2") /10
	--local myMaxTempW = getValueOrDefault("EscT+") 
	
	if demoModeOn == 1 then
      myTempL = 25.32
	  myTempW = 12.46
	end
	
	
	xTxt1 = xCoord + 4; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Wasser        Luft", modeSize.sml + CUSTOM_COLOR)
	
	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawNumber(xTxt1, yTxt1, round(myTempL,1), PREC1 + modeSize.dbl + modeAlign.le + CUSTOM_COLOR)
	lcd.drawNumber(xTxt1 +80, yTxt1, round(myTempW,1), PREC1 + modeSize.dbl + modeAlign.le + CUSTOM_COLOR)

end


------------------------------------------------- 
-- Alt ----------------------------- alt --
-------------------------------------------------
local function altWidget(xCoord, yCoord, cellHeight, name)
	local myAlt = getValueOrDefault("Alt")
	local myMaxAlt = getValueOrDefault("Alt+") 
	
	if demoModeOn == 1 then
      myAlt = 124
	  myMaxAlt = 813
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Hoehe", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "m", modeSize.sml + modeAlign.le + CUSTOM_COLOR)	
	
	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxAlt,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myAlt,1), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
 
end


------------------------------------------------- 
-- AltT ----------------------------- altT --
-- Wie Alt + Höhenansage nach 10m Differenz, vorher hoher Ton -> steigen, tiefer Ton -> sinken
-- wenn Schalter SG in der mitterlen, oder oberen Position ist.
-------------------------------------------------
local function altTalkWidget(xCoord, yCoord, cellHeight, name)
	local myAlt = getValueOrDefault("Alt")
	local myMaxAlt = getValueOrDefault("Alt+") 
	
	if demoModeOn == 1 then
      myAlt = 123
	  myMaxAlt = 814
	end
	
	local alt_dif = myAlt - alt_last
	if alt_dif >= 10 then
		if getValue ("sg") >= 0 then	--
			playTone(1200, 80, 1)
			playNumber(myAlt, 9)
		end
		alt_last = myAlt
	elseif alt_dif <= -10 then
		if getValue ("sg") >= 0 then				
			playTone(600, 80, 1)
			playNumber(myAlt, 9)
		end
		alt_last = myAlt
	end	
		
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Hoehe*", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "m", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	
	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxAlt,0), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myAlt,0), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Vertical Speed --------------------- vspeed --
-------------------------------------------------
local function vspeedWidget(xCoord, yCoord, cellHeight, name)
	local myVSpeed = getValueOrDefault("VSpd")
	local myMaxVSpeed = getValueOrDefault("VSpd+") 
	
	if demoModeOn == 1 then
      myVSpeed = 12.5
	  myMaxVSpeed = 33.46
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Steigen", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "m/s", modeSize.sml + modeAlign.le + CUSTOM_COLOR)	

	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxVSpeed,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myVSpeed,1), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- GPS								 2 Zeilen --
------------------------------------------------- 

-- Openxsensor mißbraucht AccX und AccY da OpenTx für die Anzahl der Sateliten und die Genauikeit keine Variablen hat
-- AccX ist Anzahl der Sateliten und muss mit 100 multipliziert werden. note: when there is a GPS fix 3D (or higher), then number of sat is increased by 100
-- AxxY ist HDOP und muss mit 10 multipliziert werden. Je kleiner der Wert, desto besser.  Gute Werte hat man bei einem Wert von bis 2,5
-- 2-5 good, 5-10 moderate, 10-20 fair, > 20 poor
-- 1 ideal, 1-2 excellent, 2-5 good, 5-10 moderate, 10-20 fair, >20 poor
-- Das Home Symbol wird über dist1 gesteuert

local function gpsWidget(xCoord, yCoord, cellHeight, name)
	local modeFix = {[0]="Kein Fix", [2]="2D", [3]="3D", [4]="DGPS"}
	
	local sats = getValueOrDefault("AccX") * 100
	local satfix = getValueOrDefault("AccY") * 10
	
	if demoModeOn == 1 then
      sats = 10
	  satfix = 1.3
	  homeSet = 1
	end
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "GPS", modeSize.sml + CUSTOM_COLOR)
		
	-- Icon GPS -----
	xTxt1 = xCoord + 55; yTxt1 = yCoord + 60; yTxt2 = 80
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawNumber(xTxt1, yTxt1, sats, modeSize.mid + modeAlign.le + CUSTOM_COLOR)

	gpsIndex = sats + 1
	if gpsIndex > 7 then gpsIndex = 7 end
	
	if gpsName ~= imagePath.."gps"..gpsIndex..".png" then
		gpsName = imagePath.."gps"..gpsIndex..".png"
		gpsImage = Bitmap.open(gpsName)
	end
	
	xPic= xCoord + 10; yPic= yCoord + 70
	lcd.drawBitmap(gpsImage, xPic, yPic)
			
	-- Icon satFix -----
	xPic= xCoord + 75; yPic= yCoord + 7
	
	-- fixIndex = satfix + 1
	-- ??? passen die Werte in der Praxis? Bilder 2 und 3 noch farbig machen
	if satfix >= 15 then fixIndex = 1 end
	if satfix < 15 then fixIndex = 2 end
	if satfix < 5 then fixIndex = 3 end	
	if satfix < 2 then fixIndex = 4 end
	if sats == 0 then fixIndex = 0 end
	
	
	--if fixIndex > 4 then fixIndex = 4 end
	
	if fixName ~= imagePath.."fix"..fixIndex..".png" then
		fixName = imagePath.."fix"..fixIndex..".png"
		fixImage = Bitmap.open(fixName)
	end
	
	lcd.drawBitmap(fixImage, xPic, yPic)
		
	-- Icon homeSet -----
	xPic= xCoord + 10; yPic= yCoord + 23
	
	if homeSet == 1 then homeIndex = 2 else homeIndex = 1 end
	
	if homeName ~= imagePath.."home"..homeIndex..".png" then
		homeName = imagePath.."home"..homeIndex..".png"
		homeImage = Bitmap.open(homeName)
	end
	
	lcd.drawBitmap(homeImage, xPic, yPic)
end


------------------------------------------------- 
-- Heading ------------------------------- hdg --
------------------------------------------------- 
local function headingWidget(xCoord, yCoord, cellHeight, name)
	local hdgArray = {" N ", "NNO", "NO", "ONO", " O ", "OSO", "SO", "SSO", " S ", "SSW", "SW", "WSW", " W ", "WNW", " NW ", "NNW", " N "}
	local myHeading = getValueOrDefault("Hdg") 
		
	if demoModeOn == 1 then
      myHeading = 35
	end
	
	hdgIndex = math.floor (myHeading/15+0.5) --+1
	
	if hdgIndex > 23 then hdgIndex = 23 end		-- ab 352 Grad auf Index 23
	
	xTxt1 = xCoord + cellWide * xCorr.value1; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xTxt1, yTxt1, round(myHeading), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "dg", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
	
	-- Himmelsrichtung anzeigen -----
	local direction = math.floor((myHeading + 11.25)/22.5) + 1
	lcd.setColor(CUSTOM_COLOR, col_val)
	lcd.drawText(xCoord + 4, yCoord + 2, hdgArray[direction], modeSize.sml+ modeAlign.le + CUSTOM_COLOR)

	-- Icon Heading -----
	if hdgName ~= imagePath.."pfeil"..hdgIndex..".png" then
		hdgName = imagePath.."pfeil"..hdgIndex..".png"
		hdgImage = Bitmap.open(hdgName)
	end
	
	local w, h = Bitmap.getSize(hdgImage)
	xPic= xCoord + cellWide - w - 2; yPic= yCoord + 7
	lcd.drawBitmap(hdgImage, xPic, yPic)
end


------------------------------------------------- 
-- Distance-OpenTx ---------------------- dist --
------------------------------------------------- 
local function distWidget(xCoord,yCoord, cellHeight, name)
	local myDistance = getValueOrDefault("Dist")
	local myMaxDistance = getValueOrDefault("Dist+") 
	--local myDistance = getValueOrDefault (212)
	
	if demoModeOn == 1 then
      myDistance = 250
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Entf. OTx", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "m", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	
	lcd.setColor(CUSTOM_COLOR, col_val)
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxDistance,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myDistance), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
--- Distance calculated	---------------- dist1 --
------------------------------------------------- 
local function distCalcWidget(xCoord, yCoord, cellHeight, name)
	local myLatLon = getValueOrDefault("GPS")
	
	
	if type(myLatLon) == "table" and myLatLon["lat"] * myLatLon["lon"] ~= 0 then
		LocationLat = myLatLon["lat"]
		LocationLon = myLatLon["lon"]
	else
		LocationLat = 0
		LocationLon = 0
	end


	--if MotorAn == 0 or homeSet == 0 then
	if homeSet == 0 then
		homeLat = 0
		homeLon = 0
		myDistance = 0
		myMaxDistance = 0
	end


	if homeSet == 0 and MotorAn == 1 and homeLat==0 then
		if getValueOrDefault("AccX") * 100 > 2 then		-- siehe GPS
			homeSet = 1
			homeLat = LocationLat
			homeLon = LocationLon
		end
	end
			
	-- Distanz berechnen
	if homeSet == 1 then
		local d2r = math.pi/180
		local d_lon = (LocationLon - homeLon) * d2r ;
		local d_lat = (LocationLat - homeLat) * d2r ;
		local a = math.pow(math.sin(d_lat/2.0), 2) + math.cos(homeLat*d2r) * math.cos(LocationLat*d2r) * math.pow(math.sin(d_lon/2.0), 2);
		local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
		local myDistance = 6371000 * c;
	else
		local myDistance = 0
	end
	
	if demoModeOn == 1 then
		myDistance = 265
	end

	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	
	if myMaxDistance < myDistance then myMaxDistance = myDistance end
	
	lcd.setColor(CUSTOM_COLOR, col_txt)			
	lcd.drawText(xCoord + 4, yCoord + 2, "Entf. Ber.", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "m", modeSize.sml + modeAlign.le + CUSTOM_COLOR)	
	
	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xCoord  + cellWide - 5, yCoord + 2, round(myMaxDistance,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myDistance), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)

end


---------------------------------- 
-- GPS Koordinaten        3/4 Widget --
----------------------------------
local function LatLonWidget(xCoord,yCoord, cellHeight, name)

	local LocationLat, LocationLon			-- GPS coord
	local LocLat_txt = ""					-- tmp txt var
	local LocLon_txt = ""					-- tmp txt var
	local preLat = ""						-- filler spce
	local preLon ="" 						-- filler spce
	
	local myLatLon = getValueOrDefault("GPS")
	
	if type(myLatLon) == "table" and myLatLon["lat"] * myLatLon["lon"] ~= 0 then
		LocationLat = myLatLon["lat"]
		LocationLon = myLatLon["lon"]
	else
		LocationLat = 102.12356
		LocationLon = 25.12356
	end
	
		-- check if lat <10 and build substring
	if LocationLat < 10 then
			LocLat_txt = string.sub(LocationLat,3 ,4) .. "." .. string.sub(LocationLat,5 ,8)
			preLat = "  "
	elseif LocationLat < 100 then
			LocLat_txt = string.sub(LocationLat,4 ,5) .. "." .. string.sub(LocationLat,6 ,9)
			preLat = " "
	else
			LocLat_txt = string.sub(LocationLat,5 ,6) .. "." .. string.sub(LocationLat,7 ,10)
	end

		-- check if lon <10 and build substring
	if LocationLon < 10 then
		LocLon_txt = string.sub(LocationLon,3 ,4) .. "." .. string.sub(LocationLon,5 ,8)
		preLon = "  "
	elseif LocationLon < 100 then
		LocLon_txt = string.sub(LocationLon,4 ,5) .. "." .. string.sub(LocationLon,6 ,9)
		preLon = " "
	else
		LocLon_txt = string.sub(LocationLon,5 ,6) .. "." .. string.sub(LocationLon,7 ,10)
	end
	
	local gpsLat = preLat .. string.format("%i",math.floor(LocationLat)).. "'" .. LocLat_txt .. "  "
	local gpsLon = preLon .. string.format("%i",math.floor(LocationLon)).. "'" .. LocLon_txt .. "  "
	
	
	xTxt1 = xCoord + 15; yTxt1 = yCoord + 10; xTxt2 = xCoord + 140; yTxt2 = yCoord + 35

	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xTxt1, yTxt1, "Lat: ", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "Lon: ", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 
	
	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xTxt2, yTxt1, "  " .. gpsLat, modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt2, yTxt2, "  " .. gpsLon, modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Speed ------------------------------- speed --
------------------------------------------------- 
local function speedWidget(xCoord, yCoord, cellHeight, name)

	local mySpeed = getValueOrDefault("GSpd") 		-- * 1.852 -- Umrechnung von Knoten in kmh falls erforderlich
	local myMaxSpeed = getValueOrDefault("GSpd+") 	-- * 1.852 
	
	if demoModeOn == 1 then
      mySpeed = 10.24
	  myMaxSpeed = 35.4
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Geschw.", SMLSIZE + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "km/h", modeSize.sml + modeAlign.le + CUSTOM_COLOR)
	
	lcd.setColor(CUSTOM_COLOR, col_val)
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxSpeed,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(mySpeed,1), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR) 
end


------------------------------------------------- 
-- Esc Current -------------------------- EscA --
-- Strom aus BlHeli_32 in A
-------------------------------------------------
local function EscAWidget(xCoord, yCoord, cellHeight, name)
	local myCur = getValueOrDefault("EscA")
	local myMaxCur = getValueOrDefault("EscA+") 
	
	if demoModeOn == 1 then
      myCur = 23.45
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xTxt1, yTxt2, "A", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	lcd.drawText(xCoord + 4, yCoord + 2, "Strom", modeSize.sml + CUSTOM_COLOR)	
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxCur,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myCur,1), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Esc Capacity ------------------------- EscC --
-- Verbrauchte Kapazität aus BlHeli_32 in mAh
-------------------------------------------------
local function EscCWidget(xCoord, yCoord, cellHeight, name)
	local myCapa = getValueOrDefault("EscC")
	local myMaxCapa = getValueOrDefault("EscC+") 
	
	if demoModeOn == 1 then
      myCapa = 123.45
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "Verbrauch", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "mAh", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxCapa,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myCapa,0), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)

end


------------------------------------------------- 
-- Esc RPM ------------------------------ EscR --
-- Drehzahl aus BlHeli_32 in 1/min
-------------------------------------------------
local function EscRWidget(xCoord, yCoord, cellHeight, name)
	local myRpm = getValueOrDefault("EscR")
	local myMaxRpm = getValueOrDefault("EscR+") 	
	
	if demoModeOn == 1 then
      myRpm = 7800
	  myMaxRpm = 10200
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)
	lcd.drawText(xCoord + 4, yCoord + 2, "Drehzahl", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "1/min", modeSize.sml + modeAlign.le + CUSTOM_COLOR)	
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxRpm,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myRpm,0), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)
end


------------------------------------------------- 
-- Esc Temperature ---------------------- EscT --
-- Reglertemperartur aus BlHeli_32 in Celcius
-------------------------------------------------
local function EscTWidget(xCoord, yCoord, cellHeight, name)
	local myTemp = getValueOrDefault("EscT")
	local myMaxTemp = getValueOrDefault("EscT+") 
	
	if demoModeOn == 1 then
      myTemp = 25.45
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml
	
	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Reglertemperartur", modeSize.sml + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt2, "C", modeSize.sml + modeAlign.le + CUSTOM_COLOR) 	

	lcd.setColor(CUSTOM_COLOR, col_val)		
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(myMaxTemp,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(myTemp,0), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)

end


------------------------------------------------- 
-- Fenster zum Debuggen von 2 Werten
-- debug0 klein oben, debug1 groß unten
-------------------------------------------------
local function debugWidget(xCoord, yCoord, cellHeight, name)

	local debug0 = 0
	local debug1 = 10 
	-- debug1 = getValue("ext2")
	-- debug1 = thisZone.zone.w
	
	if demoModeOn == 1 then
      debug0 = 100
	  debug1 = 200
	end
	
	xTxt1 = xCoord + cellWide * xCorr.value; yTxt1 = cellHeight + yCorr.dbl; yTxt2 = cellHeight + yCorr.sml

	lcd.setColor(CUSTOM_COLOR, col_txt)	
	lcd.drawText(xCoord + 4, yCoord + 2, "Debug", modeSize.sml + CUSTOM_COLOR)
	
	lcd.setColor(CUSTOM_COLOR, col_val)	
	lcd.drawText(xCoord + cellWide - 5, yCoord + 2, round(debug0,1), modeSize.sml + modeAlign.ri + CUSTOM_COLOR)
	lcd.drawText(xTxt1, yTxt1, round(debug1,1), modeSize.dbl + modeAlign.ri + CUSTOM_COLOR)

end


-- ############################# Ende Widgets #################################


-- ############################# Touch Buttons #################################

------------------------------------------------------------------- 
-- Button mit Text
-- Angezeigter Text kommt aus der config
-- 10 Varianten mit anderen Farben etc. bis Bt09Widget möglich
-------------------------------------------------------------------
-- !! Baustelle

local function Bt01Widget(xCoord, yCoord, cellHeight, name)
	local key_Pos		-- PPP,CCC,RRR
	local active = 0
	local slider = 0

	lcd.drawFilledRectangle(xCoord+1, yCoord+2, cellWide-1, ButtonHeight-2, COLOR_THEME_SECONDARY2)
	
	xTxt1 = xCoord +3; yTxt1 = cellHeight + yCorr.dbl;
	lcd.setColor(CUSTOM_COLOR, col_txt)
	
	lcd.drawText(xTxt1, yTxt1, string.sub(name, 6, string.len(name)), modeSize.dbl + modeAlign.le + CUSTOM_COLOR)



	-- keyPos is used as an index for pictures and an array whitch contains the status of the button (active, slider)
	key_Pos = page
	key_Pos = bit32.bor(bit32.lshift(bit32.bor(bit32.lshift(key_Pos, 3), gridColum), 3), gridRow)	-- PPP,CCC,RRR
	
	-- the array key_AS[ ] is filled by telemetry from the receiver triggered when buttos are pressed, see arduino code
	if key_AS[key_Pos] ~= nil then  
		active = bit32.rshift(key_AS[key_Pos], 6)
		slider = bit32.band(key_AS[key_Pos], 0x3F)		
	end	

	
	-- roter Rand für aktiv
	if active == 1 then
		lcd.drawRectangle(xCoord+1, yCoord+2, cellWide-1, ButtonHeight-2, RED, 3)
	end
	
	if slider > 0 then
		local xPic= xCoord + (cellWide - w) *0.5 +1; local yPic= yCoord + 3
		xPic= xCoord + (cellWide /2);
		lcd.drawLine(xPic -35, yPic +6, xPic +35, yPic +6, SOLID, ORANGE)
		lcd.drawFilledCircle(xPic +slider -32, yPic +6, 6 , ORANGE)
	end
	

	
end

----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------
-- Button mit Bild
-- Angezeigte Grafik wird aus der config zugewisen. 
-- Grafik muss in passender Größe und Beschriftung vorbereitet sein
-------------------------------------------------------------------

local function Bt10Widget(xCoord, yCoord, cellHeight, name)
	local img 
	local bm
	local key_Pos		-- PPP,CCC,RRR
	local active = 0
	local slider = 0
	
	valPng = string.sub(name, 6, string.len(name))  -- extract the file name after Bt10

	
	-- keyPos is used as an index for pictures and an array whitch contains the status of the button (active, slider)
	key_Pos = page
	key_Pos = bit32.bor(bit32.lshift(bit32.bor(bit32.lshift(key_Pos, 3), gridColum), 3), gridRow)	-- PPP,CCC,RRR
	
	-- the array key_AS[ ] is filled by telemetry from the receiver triggered when buttos are pressed, see arduino code
	if key_AS[key_Pos] ~= nil then  
		active = bit32.rshift(key_AS[key_Pos], 6)
		slider = bit32.band(key_AS[key_Pos], 0x3F)		
	end	
	
	img = bit32.bor(bit32.lshift(key_Pos, 1), active) --PPPCCCRRRA
	
		
	if bitmaps[img] ~= nil then 
      bm = bitmaps[img]
    else       
	  bm = Bitmap.open(imagePath..active..valPng..".png")
      if Bitmap.getSize(bm) == 0 then
        bm = nil
      else  
        bitmaps[img] = bm
      end  
    end
	
	
	local w, h = Bitmap.getSize(bm)
	local xPic= xCoord + (cellWide - w) *0.5 +1; local yPic= yCoord + 3
	lcd.drawBitmap(bm, xPic, yPic)  --da kann noch ein Parameter für die Scalierung dran.
	
	if slider > 0 then
		xPic= xCoord + (cellWide /2);
		lcd.drawLine(xPic -35, yPic +6, xPic +35, yPic +6, SOLID, ORANGE)
		lcd.drawFilledCircle(xPic +slider -32, yPic +6, 6 , ORANGE)
	end
	
	
end

-- ############################# Touch Buttons #################################

----------------------------------------------------------------------------------------------------------------------

-- ############################# Stick Switch #################################


local function long_half()		-- 0 kein Schalter vorhanden, 1 halb lang unbenutzt, 2 Alt, 3 mAh
	if stick_switch == 2 then
		print('sage Alt')
	elseif stick_switch == 3 then
		print('sage mAh')
	end
end


local function read_switch()
		
----reading the momentary stick switch----------------------------------------------------------------------------------------------------------------------
	
	local ms = getValue("ext2")			--read the momentary switch

	if ms > -512 and ms < 512 then		--released	
		click_state = 0
	elseif ms > 512 then				--half way pressed
		click_state = 1
	elseif ms < -512 then				--fully pressed
		click_state = 2
	end
	
	if click_state >0 and click_state_last ==0 then		--key has just been pressed
		click_time_last = getTime()						--save time when switch was pressed
	end
	
		
--  short click..............................................................................................

	if (click_state ==0) and (click_state_last >0) and (click_long== 0) then		--key has been released
		click_duration = getTime() - click_time_last	--druation of key pressed
		
		if click_duration <=50  then					-- short click		
			click_long = 1
			
			if click_state_last==1 then					--half way pressed
				playTone(800, 50, 10)
				playNumber(Vbatt*10, 1, PREC1)
			elseif click_state_last==2 then				--fully pressed			
				playTone(800, 50, 10)
				playTone(800, 50, 10)
				playDuration(model.getTimer(0).value,0)				-- Timer 1 = Flugzeit	
			end	
			click_cf_reset = 1						
		end

	end


--long click..............................................................................................	
	
	if (click_state >0) and (click_state_last >0) and (click_long== 0)  then		--key is still pressed
		click_duration = getTime() - click_time_last	--druation of key pressed
		if click_duration > 50 then						-- long click	
			click_long = 1								-- do not repeat if still long pressed
						
			if click_state==1 then						--half way pressed
				playTone(1200, 50, 10)
				--!!!!! Hier fehlt noch was!!!!
				--print('sage etwas')
				long_half()
			elseif click_state==2 then					--fully pressed
				playTone(1200, 50, 10)
				playTone(1200, 50, 10)
				playDuration(model.getTimer(1).value,0)				-- Timer 2 = Motorlaufzeit	
			end			
			click_cf_reset = 1			
		end
	end	

	
	if click_state ==0 and click_state_last == 0  then	--key is not pressed
		click_long = 0
	end	
		
	click_state_last = click_state
		
end

-- ############################# Ende Stick Switch #################################


-- ############################# Call Widgets #################################
 
local function callWidget(name, xPos, yPos, y1Pos)
	if (xPos ~= nil and yPos ~= nil) then
		if (name == "battery") or (name == "battery1") then
			batteryWidget(xPos, yPos, y1Pos, name)
		elseif (name == "rssi") or (name == "rssi1") then
			rssiWidget(xPos, yPos, y1Pos, name)
		elseif (name == "rssi2") then
			rssiWidget(xPos, yPos, y1Pos, name)
		elseif (name == "vfas") then
			vfasWidget(xPos, yPos, y1Pos, name)
		elseif (name == "curr") then
			currWidget(xPos, yPos, y1Pos, name)
		elseif (name == "rxbat") then
			rxbatWidget(xPos, yPos, y1Pos, name)
		elseif (name == "fuel") then
			fuelWidget(xPos, yPos, y1Pos, name)
		elseif (name == "fm") or (name == "fm1") then
			fmWidget(xPos, yPos, y1Pos, name)
		elseif (name == "armed") then
			armedWidget(xPos, yPos, y1Pos, name)
		elseif (name == "timer1") then
			timer1Widget(xPos, yPos, y1Pos, name)
		elseif (name == "timer2") then
			timer2Widget(xPos, yPos, y1Pos, name)			
		elseif (name == "gps") then
			gpsWidget(xPos, yPos, y1Pos, name)
		elseif (name == "latlon") then
			LatLonWidget(xPos, yPos, y1Pos, name)
		elseif (name == "speed") then
			speedWidget(xPos, yPos, y1Pos, name)
		elseif (name == "vspeed") then
			vspeedWidget(xPos, yPos, y1Pos, name)
		elseif (name == "rpm") then
			rpmWidget(xPos, yPos, y1Pos, name)
		elseif (name == "heading") then
			headingWidget(xPos, yPos, y1Pos, name)
		elseif (name == "dist") then
			distWidget(xPos, yPos, y1Pos, name)
		elseif (name == "dist1") then
			distCalcWidget(xPos, yPos, y1Pos, name)
		elseif (name == "alt") then
			altWidget(xPos, yPos, y1Pos, name)
		elseif (name == "altT") then
			altTalkWidget(xPos, yPos, y1Pos, name)
		elseif (name == "EscA") then
			EscAWidget(xPos, yPos, y1Pos, name)	
		elseif (name == "EscC") then
			EscCWidget(xPos, yPos, y1Pos, name)	
		elseif (name == "EscR") then
			EscRWidget(xPos, yPos, y1Pos, name)				
		elseif (name == "EscT") then
			EscTWidget(xPos, yPos, y1Pos, name)		
		elseif (name == "clock") then
			whatch(xPos, yPos, y1Pos, name)
		elseif (name == "Temp") then
			TempWidget(xPos, yPos, y1Pos, name)	
		--elseif (name == "Bt01") then
		elseif (string.match ( name, "Bt01")) then
			Bt01Widget(xPos, yPos, y1Pos, name)	
		elseif (string.match ( name, "Bt10")) then
			Bt10Widget(xPos, yPos, y1Pos, name)				
		elseif (name == "debug") then
			debugWidget(xPos, yPos, y1Pos, name)			
		else			
			return
		end
	end
end


-- ############################# Build Grid #################################

local function buildGrid(def, thisZone, event)

	local sumX = thisZone.zone.x
	local sumY = thisZone.zone.y
	
	local height
	local width
	
	if event == nil then -- Widget mode; event == nil
		page = 1	--when leaving full screen mode, set to page1
		widget()
		height = thisZone.zone.h	-- widget mode
		width  = thisZone.zone.w
	else
		height = LCD_H	-- full screen mode
		width  = LCD_W
	end
	
	--print("Screen H "..LCD_H)
	--print("Zone H "..height)
	--print("Screen W "..LCD_W)
	--print("Zone W "..width)	
	
	
	noCol = # def 	-- Anzahl Spalten berechnen
	cellWide = (width / noCol) - 1
				
	-- Rechteck
	--if transparency  ~= 1 then 
	if thisZone.options.transparent  ~= 1 then
	  	lcd.setColor(CUSTOM_COLOR, col_bak)
		lcd.drawFilledRectangle(thisZone.zone.x, thisZone.zone.y, width, height, CUSTOM_COLOR)
		lcd.drawRectangle(thisZone.zone.x, thisZone.zone.y, width, height, 0, 2)
	else
		lcd.drawRectangle(thisZone.zone.x, thisZone.zone.y, width, height, 0, 2)
	end
	
	-- Vertikale Linien
	lcd.setColor(CUSTOM_COLOR, col_frm)
	if noCol == 2 then
		lcd.drawLine(sumX + cellWide, sumY, sumX + cellWide, sumY + height - 1, SOLID, 0 + CUSTOM_COLOR)
	elseif noCol == 3 then
		lcd.drawLine(sumX + cellWide,   sumY, sumX + cellWide,   sumY + height - 1, SOLID, 0 + CUSTOM_COLOR)
		lcd.drawLine(sumX + cellWide*2, sumY, sumX + cellWide*2, sumY + height - 1, SOLID, 0 + CUSTOM_COLOR)
	elseif noCol == 4 then
		lcd.drawLine(sumX + cellWide,   sumY, sumX + cellWide,   sumY + height - 1, SOLID, 0 + CUSTOM_COLOR)
		lcd.drawLine(sumX + cellWide*2, sumY, sumX + cellWide*2, sumY + height - 1, SOLID, 0 + CUSTOM_COLOR)
		lcd.drawLine(sumX + cellWide*3, sumY, sumX + cellWide*3, sumY + height - 1, SOLID, 0 + CUSTOM_COLOR)
	end
	
	-- Horizontale Linien und Aufruf der einzelnen Widgets
	for i=1, noCol, 1
	do
	
	local tempCellHeight = thisZone.zone.y + (math.floor(height / # def[i])*0.35)
		for j=1, # def[i], 1
		do
			-- Horizontal Linen
			lcd.setColor(CUSTOM_COLOR, col_frm)
			if j ~= 1 then
				lcd.drawLine(sumX, sumY, sumX + cellWide, sumY, SOLID, 0 + CUSTOM_COLOR)
			end
			
			-- Widgets
			ButtonHeight = math.floor(height / # def[i])
			gridColum = i
			gridRow = j
			
			callWidget(def[i][j], sumX , sumY , tempCellHeight)
			sumY = sumY + math.floor(height / # def[i])
			tempCellHeight = tempCellHeight + math.floor(height / # def[i])
			
		end
		
		-- Werte zurücksetzen
		sumY = thisZone.zone.y
		sumX = sumX + cellWide
	end
end


-- ############################# Touch / Key Events #################################

local function send_touch_event(eventType, last_touch, page, touch_col, touch_row)

	teleSend = last_touch
	teleSend = bit32.lshift(teleSend, 3)
	teleSend = bit32.lshift(bit32.bor(teleSend, page), 3)
	teleSend = bit32.lshift(bit32.bor(teleSend, touch_col), 3)
	teleSend = bit32.bor(teleSend, touch_row)								
	print(" ")
	print("Event. "..eventType)
	print("Key. "..last_touch)
	print("Page. "..page)
	print("X. "..touch_col)
	print("Y. "..touch_row)	
	print("Down. "..teleSend)
	ret = sportTelemetryPush( 0x0D , 0x32 , eventType , teleSend)

end

local function send_key_event(eventType, key_event)
	
	ret = sportTelemetryPush( 0x0D , 0x32 , eventType , key_event)
	print("Key event: "..key_event)
	
end


local function handle_events(event, touchState, def)

	if event ~= nil then -- Full scree mode
		
		
		-- change pages by hardware keys
		if event == EVT_VIRTUAL_NEXT_PAGE and page < pages then				
			page = page + 1
			widget()
		elseif event == EVT_VIRTUAL_PREV_PAGE and page>1 then
			page = page - 1
			widget()
		end		
		
		if still_pressed > 0 then
			still_pressed = still_pressed + 1
		end
		
		-- !! Krücke wegen: [LUA] Touch events missing in action #1426
		-- send touch event for long pressed keys
		if still_pressed == 8 then		-- !! vielleicht doch über Zeit. Wischen und drücken ist noch nicht gut unterschieden
			playTone(600, 50, 100, PLAY_NOW)
			print("Still pressed")
			last_touch = 1
			print("Last touch Long "..last_touch)
			local eventType = 1 
			send_touch_event(eventType, last_touch, page, touch_col, touch_row)
		end
		
		-- send key and roll events 
		if event > 0 and touchState == nil  then
			local eventType = 2
			send_key_event(eventType, event)
		end
		
		
		
		
				
		if touchState then
		--playTone(200, 50, 100, PLAY_NOW)
			--local last_touch = 0

			if event == EVT_TOUCH_FIRST then -- A short tap on the screen gives TAP instead of BREAK
				playTone(200, 50, 100, PLAY_NOW)
				print("FIRST")
				last_touch = 1
				still_pressed = 1
				
				touch_col = math.floor(touchState.x/cellWide)+1
				touch_row = math.floor(touchState.y / (LCD_H / # def[touch_col]))+1			
				--print("Page "..page)
				--print("X "..touch_col)
				--print("Y "..touch_row)	

				
			-- !! geht noch nicht sehr gut wegen: [LUA] Touch events missing in action #1426
			elseif event == EVT_TOUCH_TAP then -- A short tap on the screen gives TAP instead of BREAK
				playTone(10000, 200, 100, PLAY_NOW, -60)
				print("TAP")
				last_touch = 3
				still_pressed = 0				
				print("Last touch TAP "..last_touch)
				
				touch_col = math.floor(touchState.x/cellWide)+1
				touch_row = math.floor(touchState.y / (LCD_H / # def[touch_col]))+1			
				--print("Page "..page)
				--print("X "..touch_col)
				--print("Y "..touch_row)	
				local eventType = 1 
				send_touch_event(eventType, last_touch, page, touch_col, touch_row)

				
			elseif event == EVT_TOUCH_SLIDE then
				if touchState.swipeLeft and page < pages then				
					playTone(100, 200, 100, PLAY_NOW, 10)	
					page = page + 1
					widget()
					--print("Page Nr "..page)		
				elseif touchState.swipeRight and page>1 then
					playTone(1000, 200, 100, PLAY_NOW, -10)
					page = page - 1
					widget()
					--print("Page Nr "..page)
				end
				last_touch = 0
			
			elseif event == EVT_TOUCH_BREAK then -- When the finger leaves the screen (and did not slide on it)        
				still_pressed = 0
				print("BREAK")
				playTone(300, 50, 100, PLAY_NOW)							
				
				if last_touch == 1  then 
					last_touch = 2
				end
				print("Last touch Break "..last_touch)
				
				if last_touch > 0 then				
					local eventType = 1 --Touch			
					send_touch_event(eventType, last_touch, page, touch_col, touch_row)					
				end
			end			
		--print("Last touch "..last_touch)
		
		end
	end



end


-- Key state (active or inactive) and slider position are set by the receiver and forwarded to the buttons while building the grid
local function handle_receiver_telemetry()
	local sensorID,frameID,dataID,payload
	local key_Pos, key_state
	
	sensorID,frameID,dataID,payload = sportTelemetryPop()
	
	if dataID~=nil then
		--PPP,CCC,RRR,A,SSSSSS	page colum active slider
		key_Pos   = bit32.rshift(payload, 7) 					 -- PPP,CCC,RRR
		key_state = bit32.band(payload, 0x007F) 				 -- A,SSSSSS
		key_AS[key_Pos] = key_state	
	end
	
end

-- ############################# Ende Touch / Key Events #################################


-- wird auch ausgeführt, wenn das Widget nicht angezeigt ist
local function background(thisZone)	
	readBat()
	
	
	if Trim5_GV1  > 0 then
		Trim5_to_GV1()		-- liest den Trimmer 5 und schreibt den Wert in GV1
	end
	
	if stick_switch > 0 then
		read_switch()
	end	
	
end


local function refresh(thisZone, event, touchState)
	readBat()

	if Trim5_GV1  > 0 then
		Trim5_to_GV1()		-- liest den Trimmer 5 und schreibt den Wert in GV1
	end
	
	if stick_switch > 0 then
		read_switch()
	end
	
	handle_events(event, touchState, widgetDefinition)
	
	if sendEvents > 0 then
		handle_receiver_telemetry()		-- kommt aus der Modellkonfiguraton
	end
	
	-- Build Grid --	
	buildGrid(widgetDefinition, thisZone, event)
	
end

return { name="Telemetrie", options=options, create=create, update=update, refresh=refresh, background=background }