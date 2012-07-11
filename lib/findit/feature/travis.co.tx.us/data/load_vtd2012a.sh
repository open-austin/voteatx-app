#!/bin/sh

SHAPEFILE_NAME="VTD2012a"

TABLENAME="travis_co_tx_us_voting_districts"
SRID=3081

. ../../load_env.sh
: ${DBNAME?} ${DBUSER?}

LOADFILE=`mktemp -t pgload-XXXXXXXX.sql`

set -e

shp2pgsql -s $SRID $SHAPEFILE_NAME $TABLENAME >$LOADFILE

cat >>$LOADFILE <<_EOT_
CREATE INDEX idx_${TABLENAME}_geom ON ${TABLENAME} USING gist(the_geom);
VACUUM FULL ${TABLENAME};
_EOT_

psql -d $DBNAME -h localhost -U $DBUSER -f $LOADFILE </dev/null
rm -f $LOADFILE

