wget -N "https://www.enedis.fr/contenu-html/opendata/Postes%20source%20(postes%20HTBHTA).zip"
# wget -N "https://www.enedis.fr/contenu-html/opendata/Lignes%20a%C3%A9riennes%20moyenne%20tension%20(HTA).zip"
# wget -N "https://www.enedis.fr/contenu-html/opendata/Lignes%20souterraines%20moyenne%20tension%20(HTA).zip"
wget -N "https://www.enedis.fr/contenu-html/opendata/Postes%20de%20distribution%20publique%20(postes%20HTABT).zip"
# wget -N "https://www.enedis.fr/contenu-html/opendata/Lignes%20a%C3%A9riennes%20Basse%20Tension%20(BT).zip"
# wget -N "https://www.enedis.fr/contenu-html/opendata/Lignes%20souterraines%20Basse%20Tension%20(BT).zip"

unzip "Postes source (postes HTBHTA).zip" "Poste_Source.shp"
unzip "Postes de distribution publique (postes HTABT).zip" "Poste_Electrique.shp"

# ogr2ogr -f postgresql PG:dbname=osm -nln enedis_poste_source -t_srs EPSG:4326 Poste_Source.shp -overwrite
# ogr2ogr -f postgresql PG:dbname=osm -nln enedis_poste_electrique -t_srs EPSG:4326 Poste_Electrique.shp -overwrite
