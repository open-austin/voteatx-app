#!/bin/sh

do_download=false
do_unpack=true

URL="ftp://ftp.ci.austin.tx.us/GIS-Data/Regional/regional/facilities.zip"
ZIPFILE="facilities.zip"
UNPACKED_FILES="facilities.dbf facilities.prj facilities.sbn facilities.sbx facilities.shp facilities.shp.xml facilities.shx"
SHAPEFILE_NAME="facilities"

TABLENAME=austin_ci_tx_us_facilities
SRID=2277

. ../../load_env.sh
: ${DBNAME?} ${DBUSER?}

$do_download && wget "$URL"

$do_unpack && unzip $ZIPFILE

LOADFILE=`mktemp -t pgload-XXXXXXXX.sql`

set -e

shp2pgsql -s $SRID $SHAPEFILE_NAME $TABLENAME >$LOADFILE 

cat >>$LOADFILE <<_EOT_
CREATE INDEX idx_${TABLENAME}_geom ON ${TABLENAME} USING gist(the_geom);
CREATE INDEX idx_${TABLENAME}_facility ON ${TABLENAME} USING hash(facility);
VACUUM FULL ${TABLENAME};
_EOT_

psql -d $DBNAME -h localhost -U $DBUSER -f $LOADFILE </dev/null
rm -f $LOADFILE

$do_unpack && rm -f $UNPACKED_FILES

$do_download && rm -f $ZIPFILE
