#!/bin/sh
# -*- coding: utf-8 -*-

bq_name="userbouquet.skyicam_single.tv"
bq_datei_local="/etc/enigma2/${bq_name}"
bq_datei_online="https://github.com/AlexanderSch90/sat-bou/raw/main/${bq_name}"
tmp_datei="/tmp/${bq_name}"
log_datei="/tmp/bouquet.log"
log_datei_max=65000
bq_eintrag="#SERVICE 1:7:1:0:0:0:0:0:0:0:FROM BOUQUET \"$bq_name\" ORDER BY bouquet"

hilfe_nachricht="ohne Argumente ausführen"

bqLog() 
{
    if [ "${1:0:3}" = "===" ]; then
        logmsg="$1"
    else
        logmsg=$(echo "$1" | sed "s/^/`date '+%Y-%m-%d %H:%M:%S'` /")
    fi   
    #echo "$logmsg" > /dev/null                  ### Log wird deaktiviert
    echo "$logmsg" 2>&1 | tee -a $log_datei       ### Log wird aktiviert
    if [ -f "$log_datei" ] && [ $(wc -c <"$log_datei") -gt $log_datei_max ]; then sed -i -e '1,20d' "$log_datei"; fi
}

ist_standby() {
	[ "$(wget -q -O - http://127.0.0.1/web/powerstate | grep '</e2instandby>' | cut -f 1)" = "true" ]
}

not_standby() {
	[ "$(wget -q -O - http://127.0.0.1/web/powerstate | grep '</e2instandby>' | cut -f 1)" = "false" ]
}

standby() {
    wget -O - -q http://127.0.0.1/web/powerstate?newstate=5 >/dev/null 2>&1 > /dev/null 2>&1
    sleep 5
}

wakeup() {
    wget -O - -q http://127.0.0.1/web/powerstate?newstate=4 >/dev/null 2>&1 > /dev/null 2>&1
}

services_neu_laden() {
    wget -q -O - "http://127.0.0.1/web/servicelistreload?mode=0" > /dev/null 2>&1
    sleep 1
    wget -q -O - "http://127.0.0.1/web/servicelistreload?mode=4" > /dev/null 2>&1
    bqLog "Die Servicelisten wurden neu geladen (userbouquet.*.tv / .radio , userbouquets.tv , lamedb)"
}

update_austausch_userbouquet() {

        mv -f $tmp_datei $bq_datei_local
        bqLog "$bq_datei_local wurde aktualisiert"
}

pruef_austausch_userbouquet() {
    rm -f $tmp_datei
    
    if wget -q -O $tmp_datei "$bq_datei_online" > /dev/null 2>&1; then
        bqLog "$bq_datei_online wurde heruntergeladen"
    if [ -f "$tmp_datei" ] && diff -aw $tmp_datei $bq_datei_local > /dev/null 2>&1; then
        bqLog "$bq_datei_local wurde nicht aktualisiert (der Inhalt der Dateien ist derselbe)"
    else
        if ist_standby; then
            update_austausch_userbouquet
            services_neu_laden
			
		elif not_standby; then
			echo "Box ist nicht im Standby Modus"
			echo "Box geht in Standy und aktualisiert $bq_datei_local"
			standby
			update_austausch_userbouquet
			services_neu_laden
			echo "Box aufwachen"
			wakeup
        else
            bqLog "Sript wurde beendet"
        fi
    fi 
    else
        bqLog "$bq_datei_online download fehlgeschlagen!"
    fi
    
}

# eigentliches Skript
if [ "$#" -eq 0 ]; then
    # Wenn keine Argumente �bergeben wurden, f�hre die Update-Aktion aus
        if ! cat /etc/enigma2/bouquets.tv | grep -w "$bq_eintrag" > /dev/null; then
            sed -i "2 a $bq_eintrag" /etc/enigma2/bouquets.tv
            [ -f $bq_datei_local ] || touch $bq_datei_local 
        fi
        pruef_austausch_userbouquet
else
    # Ansonsten zeige die Hilfe-Nachricht
    echo "$hilfe_nachricht"
fi

rm -f $tmp_datei
bqLog "---------------------------------------------------"

exit 0
