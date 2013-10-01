#!/bin/sh

USAGE="usage: $0 database_file table_name"

case "$#" in
	1) DBFILE="$1" TABLENAME="travis_co_tx_us_voting_districts" ;;
	2) DBFILE="$1" TABLENAME="$2" ;;
	*) echo "$USAGE" >&2 ; exit 1 ;;
esac

if [ ! -f "$DBFILE" ] ; then
	echo "$0: database file \"$DBFILE\" not found" >&2
	exit 1
fi

SHAPEFILE="VTD2012a"
CODEPAGE="CP1252"
SRID="3081"

set -x
spatialite_tool -i -shp "$SHAPEFILE" -d "$DBFILE" -t "$TABLENAME" -c "$CODEPAGE" -s "$SRID"

