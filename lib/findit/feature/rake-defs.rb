BASEDIR = File.dirname(__FILE__) + "/../../.."
$:.insert(0, BASEDIR + "/lib")

DATADIR = File.dirname(__FILE__) + "/data"
DATABASE = DATADIR + "/findit.sqlite"

require "findit/database"

module FindIt

  # This module can be included in "Find It" Rakefile's
  # that manage data sources.
  #
  # They typically are found in: findit/local/<i>locality</i>/data/<i>dataset</i>
  #
  module RakeDefs

    # Connection to the PostGIS/Postgresql database.
    #
    # This connects as user "postgres" and no password. This will
    # work if you run this as a user that has permissions to access
    # the database in the "postgres" role.
    #
    # The "findit" role is not sufficient, because this needs to
    # make entries into the GIS tables.
    #
    DB = FindIt::Database.connect(DATABASE, :spatialite => "/usr/lib/libspatialite.so.3")

    # Execute a SQL command on the connected database.
    #
    # Displays command to stderr.
    #
    def db_execute(cmd)
      $stderr.puts("+ " + cmd)
      DB.execute(cmd)
    end

    # Run the "shp2pgsql" command on a shape file and load the output.
    def db_load_shapefile(table, shapefile, srid, codepage = "CP1252")      
      cmdv = ["spatialite_tool", "-i",
        "-shp", shapefile,
        "-d", DATABASE,
        "-t", table,
        "-c", codepage,
        "-s", srid,
      ]
      $stderr.puts("+ " + cmdv.join(' '))
      system(cmdv)
    end

    def db_create_index(table, column, idxtype = "hash")
      db_execute("CREATE INDEX idx_#{table}_#{column} ON #{table} USING #{idxtype}(#{column})")
    end

    def db_vacuum(table)
      db_execute("VACUUM FULL #{TABLENAME}")
    end

    def db_table_exists?(table)
      DB.tables.include?(table)
    end

    def db_drop_table(table)
      db_execute("DROP TABLE #{TABLENAME}")
    end

  end # module RakeDefs
end # module FindIt

