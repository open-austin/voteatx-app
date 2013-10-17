#!/bin/sh

USAGE="usage: $0 database_file [table_name]"
DATADIR=`dirname $0`

case "$#" in
	1) DBFILE="$1" TABLENAME="travis_co_tx_us_voting_districts" ;;
	2) DBFILE="$1" TABLENAME="$2" ;;
	*) echo "$USAGE" >&2 ; exit 1 ;;
esac

SHAPEFILE="$DATADIR/VTD2012a"
CODEPAGE="CP1252"
SRID="3081"

cat <<_EOT_
-- Source --
Shape File: $SHAPEFILE

-- Destination --
Database file: $DBFILE
Database table: $TABLENAME

_EOT_

set -x
spatialite_tool -i -shp "$SHAPEFILE" -d "$DBFILE" -t "$TABLENAME" -c "$CODEPAGE" -s "$SRID"

