-- #################### Definition der Widgets #################
-- Definition der angezeigten Telemetrie-Werte in Abhängigkeit des aktiven Modells
-- Der Modellname und die Telemetriewerte müssen auf die eigenen Bedürfnisse angepasst werden


-- #################### Definition des verwendeten Akkus #################
-- v_field > Telemetrie Spannungsquelle VFAS, A2 etc
-- celTxt  > Text für die Anzeige der Zellenzahl
-- capa    > Kapazität des Akkus in mAh
-- cells   > dividiert die Eingangsspannung, für Anzeige der Durchschnittspannung pro Pack, oder Korrekturwert
-- MIN_V   > Zellenmindestspannung für Anzeige
-- MAX_V   > Zellenmaximalspannung für Anzeige
-- WARN_V  > Spannung ab der die Akkuspannung angesagt werden soll


-- !!!!! ACHTUNG für neue Modelle: Script starten und Sensorsuche erneut ausführen, es wird ein Sensor Vcel erzeugt um die Akkuspannung anzuzeigen !!!


function widget()
	stick_switch = 0

	modelName = model.getInfo().name
	
	if modelName == "Screens" then 
		demoModeOn = 1
		pages = 3
		akku = {v_field="VFAS", celTxt="3s", capa=2301, cells= 3, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
		--akku = {v_field="A2", celTxt="3s", capa=2300, cells= 1, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
		--stick_switch = 2	-- 0 kein Schalter vorhanden, 1 halb lang unbenutzt, 2 Alt, 3 mAh
				
		if page == 1 then
			--widgetDefinition = {{"gps","battery1"},{"fm1","dist1","alt","speed"}, {"rssi1", "heading", "timer1", "latlon"}}
			--widgetDefinition = {{"rssi2","battery1"},{"armed","dist1","altT","speed"}, {"rssi1", "heading", "timer1", "latlon"}}
			--widgetDefinition = {{"rssi2","battery1"},{"armed","timer1","timer2"}, {"altT", "speed", "dist1", "clock"}}
			widgetDefinition = {{"battery","timer1"},{"battery"}, {"altT", "speed", "dist1", "clock"}}
		elseif  page == 2 then
			widgetDefinition = {{"rssi2","battery1"},{"armed","dist1","alt","speed"}, {"gps", "heading"}}
			--widgetDefinition = {{"gps","battery1"},{"fm1","dist1","alt","speed"}, {"rssi1", "dist", "timer1", "latlon"}}
		elseif  page == 3 then
			widgetDefinition = {{"rssi2","battery1"},{"armed","dist1","alt","speed"}, {"gps", "heading"}}
			--widgetDefinition = {{"gps","battery1"},{"fm1","dist1","alt","speed"}, {"rssi1", "dist", "timer1", "latlon"}}		
		end
	
	elseif modelName == "Baron"  then
		akku = {v_field= "EscV", celTxt="3s", capa=1302, cells= 3, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
		stick_switch = 3	-- 0 kein Schalter vorhanden, 1 halb lang unbenutzt, 2 Alt, 3 mAh
		widgetDefinition = {{"rssi2","battery1"},{"armed","timer1","timer2","EscC"}, {"EscA", "EscT", "EscR", "clock"}}
		
	elseif modelName == "Kitty2" then
		akku = {v_field= "EscV", celTxt="3s", capa=2200, cells= 3, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
		stick_switch = 3	-- 0 kein Schalter vorhanden, 1 halb lang unbenutzt, 2 Alt, 3 mAh
		widgetDefinition = {{"rssi2","battery1"},{"armed","timer1","timer2","EscC"}, {"EscA", "EscR", "EscT", "clock"}}		
		
	elseif modelName == "Panda Sport" then
		akku = {v_field="a1", celTxt="3s", capa=1301, cells= 1, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
		widgetDefinition = {{"rssi2","battery1"},{"armed","timer1","timer2"}, {"altT", "vspeed", "clock"}}
		
	elseif modelName == "ESP" then
		akku = {v_field="VFAS", celTxt="3s", capa=1301, cells= 3, MIN_V=3.5, MAX_V=4.0, WARN_V=3.54}
		pages = 3
		
		if page == 1 then	
			widgetDefinition = {{"rssi2","battery1"},{"armed","timer1","timer2"}, {"EscC", "Temp", "clock"}}
		elseif page == 2 then	
			widgetDefinition = {{"rssi2","battery1"},{"armed","EscA","EscR","EscT"}, {"Bt01         HUPE", "Bt01 POS.LICHT", "Bt10 Pumpe", "Bt10 Licht",}}
		elseif page == 3 then				
			widgetDefinition = {{"Bt01  MP3-01", "Bt01  MP3-05", "Bt01  MP3-09", "Bt01  MP3-13", "Bt01  MP3-17"}, {"Bt01  MP3-02", "Bt01  MP3-06", "Bt01  MP3-10", "Bt01  MP3-14", "Bt01  MP3-18"}, {"Bt01  MP3-03", "Bt01  MP3-07", "Bt01  MP3-11", "Bt01  MP3-15", "Bt01  MP3-19"}, {"Bt01  MP3-04", "Bt01  MP3-08", "Bt01  MP3-12", "Bt01  MP3-16", "Bt01     STOP"}}
		end
	
	elseif modelName == "Rage 210 KISS" then
		-- Kiss FC
		widgetDefinition = {{"battery"},{"vfas","curr","fuel"}, {"fm", "armed", "timer1"}}
	elseif modelName == "TEST" or "Mini Ellipse" then
		-- Unisens E
		widgetDefinition = {{"fm","timer1","rssi"}, {"alt", "vspeed", "rxbat"}}
	else
	--local widgetDefinition = {{"vfas","timer1","curr","fuel"},{"fm1","alt","speed"}, {"timer1","curr"}}

	end
end