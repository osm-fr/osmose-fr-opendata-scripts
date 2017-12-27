# download BAN ODbL au format json
wget http://bano.openstreetmap.fr/BAN_odbl/BAN_odbl.json.bz2
bzip2 -d BAN_odbl.json.bz2

# extraction des lat/lon des adresses
echo 'lat,lon' > BAN_odbl.csv
sed 's/{"lat":/\n{"lat":/g' BAN_odbl.json | grep '^{"lat".*[0-9]}' -o | jq -r '"\(.lat),\(.lon)"' >> BAN_odbl.csv

# import dans postgis
psql osm -c "drop table if exists ban_latlon; create table ban_latlon (lat numeric, lon numeric);"
psql osm -c "\copy ban_latlon from BAN_odbl.csv with (format csv, header true)"
psql osm -c "alter table ban_latlon add geom geometry; update ban_latlon set geom = st_transform(st_setsrid(st_makepoint(lon,lat),4326),3857);"
psql osm -c "create index ban_latlon_geom on ban_latlon using gist (geom);"
