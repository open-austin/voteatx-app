#!/bin/sh

DBNAME="../../../../../../findit.sqlite"
TABLENAME="travis_co_tx_us_voting_districts"

SHAPEFILE="VTD2012a"
CODEPAGE="CP1252"
SRID="3081"

set -x
spatialite_tool -i -shp ${SHAPEFILE} -d ${DBNAME} -t ${TABLENAME} -c ${CODEPAGE} -s ${SRID}

