require "dbi"

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
    DB = DBI.connect("DBI:Pg:host=localhost;database=findit", "postgres")
    
    # Path to shp2pgsql utility.
    #
    # I need this because my Ubuntu system does not put it in
    # a public bin directory.
    #
    SHP2PGSQL = "/usr/lib/postgresql/9.1/bin/shp2pgsql"
    
    
    # Execute a SQL command on the connected database.
    #
    # Displays command to stderr.
    #
    def db_execute(cmd)
      $stderr.puts("+ " + cmd)
      DB.execute(cmd)
    end
    
    # Run the "shp2pgsql" command on a shape file and load the output.
    def db_load_shapefile(table, shapefile, srid)    
      IO.popen([SHP2PGSQL, "-s", srid, shapefile, table]) do |pp|
        save_lines = []
        pp.each_line do |line|
          next if line =~ /^--/
          save_lines << line.strip!
          next unless line =~ /;$/
          db_execute(save_lines.join(' '))
          save_lines = []
        end
      end  
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
  