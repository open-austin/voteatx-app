#!/bin/sh

do_download=false
do_unpack=true

URL="ftp://ftp.ci.austin.tx.us/GIS-Data/Regional/regional/historical.zip"
ZIPFILE="historical.zip"
UNPACKED_FILES="historical_landmarks.prj historical_landmarks.sbn historical_landmarks.sbx historical_landmarks.shp historical_landmarks.shp.xml historical_landmarks.shx historical_landmarks.dbf"
SHAPEFILE_NAME="historical_landmarks"

TABLENAME="austin_ci_tx_us_historical"
SRID="2277"

. ../../load_env.sh
: ${DBNAME?} ${DBUSER?}

$do_download && wget "$URL"

$do_unpack && unzip $ZIPFILE

LOADFILE=`mktemp -t pgload-XXXXXXXX.sql`

set -e

shp2pgsql -s $SRID $SHAPEFILE_NAME $TABLENAME >$LOADFILE

cat >>$LOADFILE <<_EOT_
CREATE INDEX idx_${TABLENAME}_geom ON ${TABLENAME} USING gist(the_geom);
CREATE INDEX idx_${TABLENAME}_building_n ON ${TABLENAME} USING hash(building_n);
VACUUM FULL ${TABLENAME};
_EOT_

psql -d $DBNAME -h localhost -U $DBUSER -f $LOADFILE </dev/null
rm -f $LOADFILE

$do_unpack && rm -f $UNPACKED_FILES

$do_download && rm -f $ZIPFILE
