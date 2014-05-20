require 'findit-support'
require 'logger'
require 'csv'
require 'yaml'
require 'pp' # for debug

class NilClass
  def empty?
    true
  end
end

module VoteATX


  # Load a geospatial "shape" file with voting districts into a Spatialite database.
  #
  # Uses the "spatialite_tool" command to do the loading.
  #
  # Requires a parameters file with YAML definitions for: shapefile, codepage, srid
  #
  class VotingDistrictsLoader

    REQUIRED_PARAMETERS = %w(shapefile codepage srid)
    SPATIALITE_TOOL = "spatialite_tool"

    # Construct a voting district loader.
    #
    # Supported parameters:
    # * :database - Name of the database to load. Required.
    # * :table - Name of the database table to create. Required.
    # * :shp_defs - File that defines parameters for the import. Required.
    # * :loader - Program to use for loading. Defaults to SPATIALITE_TOOL.
    # * :log - A Logger instance. Default is to create a new one logging to stderr.
    #
    # Example "shp_defs" file:
    #
    #     shapefile: VTD2012a.shp
    #     codepage: CP1252
    #     srid: 3081
    #
    def initialize(params)
      @database = params.delete(:database) or raise "required parameter \":database\" not specified"
      @table = params.delete(:table) or raise "required parameter \":table\" not specified"
      @shp_defs = params.delete(:shp_defs) or raise "required parameter \":shp_defs\" not specified"
      @loader = params.delete(:loader) || SPATIALITE_TOOL
      @log = params.delete(:log) || Logger.new($stderr)
      raise "unknown parameter(s): #{params.keys.join(', ')}" unless params.empty?

      @log.info("loading voting district parameters from \"#{@shp_defs}\" ...")
      @shp = YAML.load_file(@shp_defs)
      REQUIRED_PARAMETERS.each do |p|
        raise "#{@shp_defs}: required parameter \"#{p}\" undefined" unless @shp.has_key?(p)
      end

      unless @shp["shapefile"] =~ %r{^/}
        @shp["shapefile"].insert(0, File.dirname(@shp_defs) + "/")
      end
    end


    # Execute the shapefile import.
    def load
      @log.info("starting import of voting districts")
      @log.info("  source file: #{@shp['shapefile']}")
      @log.info("  target database: #{@database}")
      @log.info("  target table: #{@table}")

      cmd = [
        @loader,
        "-i",
        "-shp",
        @shp['shapefile'].sub(/\.shp$/i, ''),
        "-d",
        @database,
        "-t",
        @table,
        "-c",
        @shp["codepage"],
        "-s",
        @shp["srid"],
      ]
      @log.info("executing: #{cmd.join(' ')}")
      raise "command failed" unless system(*cmd)
    end


    # Convenience for: 
    #
    #   new(params).load
    #
    def self.load(params)
      new(params).load
    end

  end

  # Load a Spatialite database with voting place information from spreadsheets.
  #
  # The database must already exist, and must already be initialized with
  # the geospatial tables.
  #
  class VotingPlacesLoader

    # Default mapping of identifiers to spreadsheet column names
    #
    # Used to initialize @col_id_to_names when constructing a new loader.
    #
    DEFAULT_COL_IDS = {
      :SITE_NAME => ["Name", "Site Name"],
      :PCT => ["Pct", "Pct."],
      :COMBINED_PCTS => ["Combined Pcts."],
      :LOCATION_ADDRESS => ["Address", "Site Address"],
      :LOCATION_CITY => ["City"],
      :LOCATION_ZIP => ["Zipcode", "Zip Code"],
      :LOCATION_LONGITUDE => ["Longitude"],
      :LOCATION_LATITUDE => ["Latitude"],
      :SCHEDULE_CODE => ["Hours"],
      :SCHEDULE_DATE => ["Date"],
      :SCHEDULE_TIME_OPENS => ["Start Time"],
      :SCHEDULE_TIME_CLOSES => ["End Time"],
    }

    # Name of the database we are creating
    attr_reader :dbname

    # True if loader instance was constructed with :debug flag
    attr_reader :debug

    # Logger instance
    attr_reader :log

    # Spatialite database instance
    attr_reader :db

    # Mapping of data columns identifiers to spreadsheet column names.
    #
    # The column names have been known to change in different
    # data dumps -- sometimes even among sheets in a single dump.
    #
    # This table maps site ids, such as :SITE_NAME, to a list
    # of names that may appear in the spreadsheet as a title
    # for the corresponding column.
    #
    # When a new instance is constructed, this is initialized to
    # DEFAULT_COL_IDS. If you encounter changes to the spreadsheets,
    # best practice would be to update the DEFAULT_COL_IDS value.
    # (Unless the change is a one-off situation, in which case you might
    # want to just patch the table created in the instance.)
    #
    attr_accessor :col_id_to_names

    # Mapping of data column identifers to spreadsheet column index values.
    #
    # See the "@col_id_to_names" discussion.
    #
    # This table maps the index to column index number for the spreadsheet
    # currently being processed. This is managed automatically by the
    # FIXME method.
    #
    attr_reader :col_id_to_index

    # Numeric range for valid longitude (degrees) values
    attr_accessor :valid_lng_range

    # Numeric range for valid latitude (degrees) values
    attr_accessor :valid_lat_range

    # Regexp to validate zipcode values
    attr_accessor :valid_zip_regexp

    # A one-line description of the election
    #
    # Example: "for the Nov 5, 2013 general election in Travis County"
    #
    # In the VoteATX app this is displayed below the title of the
    # voting place (e.g. "Precinct 31415").
    #
    attr_accessor :election_description

    # Additional information about the election.
    #
    # This is included near the bottom of the info window that is
    # opened up for a voting place. Full HTML is supported. Line
    # breaks automatically inserted.
    #
    # This would be a good place to put a link to the official
    # county voting page for this election.
    #
    attr_accessor :election_info

    # Create individual precinct records from a single combined
    # precinct record.
    #
    # If false (the default), there should be an entry in the
    # dataset for every precinct.
    #
    # If true, combined precincts are represented by a single
    # entry.
    #
    attr_accessor :explode_combined_precincts

    # Create a new loader instance.
    #
    # The "dbname" is the name of the Spatialiate database to load. It
    # must already exist and it must already be initialized with geospatial
    # tables.
    #
    # Options:
    # * :log - A Logger instance.
    # * :debug - If true, database operations will be logged.
    #
    def initialize(dbname, options = {})
      @dbname = dbname
      @debug = options.has_key?(:debug) ? options.delete(:debug) : false

      @explode_combined_precincts = options.has_key?(:explode_combined_precincts) ? options.delete(:explode_combined_precincts) : false

      @log = options.delete(:log) || Logger.new($stderr)
      @log.level = (@debug ? Logger::DEBUG : Logger::INFO)

      raise "database \"#{@dbname}\" file does not exist" unless File.exist?(@dbname)
      @db = Sequel.spatialite(@dbname)
      @db.logger = @log
      @db.sql_log_level = :debug

      @col_id_to_names = DEFAULT_COL_IDS.dup
      @col_id_to_index = {}
      @valid_lng_range = -180 .. 180
      @valid_lat_range = -180 .. 180
      @valid_zip_regexp = /^\d\d\d\d\d(-\d\d\d\d)?$/

      @log.info("loading database \"#{@dbname}\" ...")
    end


    # Setup the @col_id_to_idx table to map column identifiers (such
    # as :PCT) to their index into the row.
    #
    # This should be called each time a CSV row is processed. (Will
    # do nothing if a current mapping already is defined.)
    #
    # Typically this is done automatically by add_row_methods().
    #
    def init_col_id_to_idx_table(row)

      # Mapping is up-to-date.
      return if ! @col_id_to_idx.empty? && @col_id_to_idx[:__ROWS] == row.headers()

      @col_id_to_idx = {:__ROWS => row.headers()}

      @col_id_to_names.each do |id, names|
	names.each do |name|
	  if row.has_key?(name)
	    @col_id_to_idx[id] = row.index(name)
	    break
	  end
	end
      end
#pp({'@col_id_to_idx' => @col_id_to_idx})

    end
    private :init_col_id_to_idx_table


    # Add the field_by_id() method to this row.
    #
    # Also initializes the @col_id_to_idx table, with column mapping
    # information for the CSV currently being processed.
    #
    # Typically, this is done automatically by cleanup_row().
    #
    def add_row_methods(row)

      init_col_id_to_idx_table(row)

      class << row
        attr_accessor :col_id_to_idx

	# Get a cell value from the spreadsheet row, identifed by column id
	# The column id maps to a column name -- or group of possible names.
        def field_by_id(id, args = {})
	  empty_ok = args.has_key?(:empty_ok) ? args[:empty_ok] : false
	  idx = @col_id_to_idx[id]
	  raise "Invalid column id \"#{id}\" for row: #{row}" unless idx
	  value = self.field(idx)
	  if value.empty? && ! empty_ok
	    raise "Required field \"#{id}\" (index #{idx}) empty for row: #{row}"
	  end
#pp({'id' => id, 'idx' => idx, 'value' => value})
	  return value
	end
      end

      row.col_id_to_idx = @col_id_to_idx
    end
    private :add_row_methods


    # Cleanup a row of data read from the spreadsheet.
    #
    # Also calls (private method) add_row_methods() to setup required
    # methods and information for this row.  Thus, it's important to
    # call this method on a row before doing anything else
    #
    def cleanup_row(row)

      # Add field_by_id() support for this row.
      add_row_methods(row)

      # Execute a value-specific cleanup on each column.
      row.each {|k,v| row[k] = v.cleanup}

      # Convert "Combined @ 109 Parmer Lane Elementary School" -> "Parmer Lane Elementary School"
      row.field_by_id(:SITE_NAME).sub!(/^Combined\s+@\s+\d+\s+/, "")

    end

    # Extract date as [mm,dd,yyyy] from specified col, in form "MM/DD/YYYY"
    def get_date(row, id)
      m = row.field_by_id(id).match(%r[^(\d{1,2})/(\d{1,2})/(\d\d\d\d)$])
      raise "bad #{id} value \"#{row.field_by_id(id)}\": #{row}" unless m && m.length-1 == 3
      m.captures.map {|s| s.to_i}
    end

    # Extract time as [hh,mm] from specified col, in form "HH:MM"
    def get_time(row, id)
      m = row.field_by_id(id).match(%r[^(\d{1,2}):(\d\d)$])
      raise "bad #{id} value \"#{row.field_by_id(id)}\": #{row}" unless m && m.length-1 == 2
      m.captures.map {|s| s.to_i}
    end

    # Produce (start_time .. end_time) range from info in database record
    def get_datetimes(row)
      mm, dd, yyyy = get_date(row, :SCHEDULE_DATE)
      start_hh, start_mm = get_time(row, :SCHEDULE_TIME_OPENS)
      end_hh, end_mm = get_time(row, :SCHEDULE_TIME_CLOSES)
      Time.local(yyyy, mm, dd, start_hh, start_mm) .. Time.local(yyyy, mm, dd, end_hh, end_mm)
    end

    # Determine if an open..close Time range is the indicator for a closed day (0:00 to 0:00).
    def is_closed_today(h)
      h.first == h.last && h.first.hour == 0 && h.first.min == 0
    end

    # Given a list of open..close Time ranges, produce a display as a list of String values.
    def format_schedule(hours)
      sched = []
      curr = nil
      hours.each do |h|

        date = format_date(h.first)
        hours = if is_closed_today(h)
            "closed"
          else
            format_time(h.first) + " - " + format_time(h.last)
          end

        if curr
          if curr[:hours] == hours
            curr[:date_last] = date
            curr[:formatted] = curr[:date_first] + " - " + curr[:date_last] + ": " + curr[:hours]
            next
          end
          sched << curr[:formatted]
        end

        curr = {
          :date_first => date,
          :date_last => date,
          :hours => hours,
          :formatted => date + ": " + hours,
        }

      end
      sched << curr[:formatted] if curr
      sched
    end

    # Given an open..close Time range, format the hours that day as a String
    def format_schedule_line(h)
      if is_closed_today(h)
        format_date(h.first) + ": closed"
      else
        format_date(h.first) + ": " + format_time(h.first) + " - " + format_time(h.last)
      end
    end

    # Format the date portion of a Time value to a String
    def format_date(t)
      t.strftime("%a, %b %-d")
    end

    # Format the time portion of a Time value to a String
    def format_time(t)
      t.strftime("%-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
    end

    # Initialize all the tables
    def create_tables
      @log.info("create_tables: creating database tables ...")

      @log.debug("create_tables: creating table \"election_defs\" ...")
      @db.create_table :election_defs do
        String :name, :index => true, :size => 16, :null => false
        Text :value
      end
      @db[:election_defs] << {:name => "ELECTION_DESCRIPTION", :value => @election_description}
      @db[:election_defs] << {:name => "ELECTION_INFO", :value => @election_info}

      @log.debug("create_tables: creating table \"voting_locations\" ...")
      @db.create_table :voting_locations do
        primary_key :id
        String :name, :size => 20, :null => false
        String :street, :size => 40, :null => false
        String :city, :size => 20, :null => false
        String :state, :size=> 2, :null => false
        String :zip, :size => 10, :null => false
        Text :formatted, :null => false
      end
      rc = @db.get{AddGeometryColumn('voting_locations', 'geometry', 4326, 'POINT', 'XY')}
      raise "AddGeometryColumn failed (rc=#{rc})" unless rc == 1
      rc = @db.get{CreateSpatialIndex('voting_locations', 'geometry')}
      raise "CreateSpatialIndex failed (rc=#{rc})" unless rc == 1

      @log.debug("create_tables: creating table \"voting_schedules\" ...")
      @db.create_table :voting_schedules do
        primary_key :id
        Text :formatted, :null => false
      end

      @log.debug("create_tables: creating table \"voting_schedule_entries\" ...")
      @db.create_table :voting_schedule_entries do
        primary_key :id
        foreign_key :schedule_id, :voting_schedules, :null => false
        DateTime :opens, :null => false, :index => true
        DateTime :closes, :null => false, :index => true
      end

      @log.debug("create_tables: creating table \"voting_places\" ...")
      @db.create_table :voting_places do
        primary_key :id
        String :place_type, :index => true, :size => 16, :null => false
        String :title, :size => 80, :null => false
        Integer :precinct, :unique => true, :null => true
        foreign_key :location_id, :voting_locations, :null => false
        foreign_key :schedule_id, :voting_schedules, :null => false
        Text :notes
      end
    end


    # Create an entry in the "voting_locations" table for this location,
    # return database row id.
    #
    # If the location already exists in the database, will return database
    # row id for existing row.
    #
    # The "row" parameter is a CSV row that must define: :SITE_NAME,
    # :LOCATION_ADDRESS, :LOCATION_CITY, :LOCATION_ZIP, :LOCATION_LONGITUDE,
    # :LOCATION_LATITUDE.
    #
    def make_location(row)

      lng = row.field_by_id(:LOCATION_LONGITUDE).to_f
      raise "longitude \"#{lng}\" outside of expected range (#{@valid_lng_range}): #{row}" unless @valid_lng_range.include?(lng)

      lat = row.field_by_id(:LOCATION_LATITUDE).to_f
      raise "latitude \"#{lat}\" outside of expected range (#{@valid_lat_range}): #{row}" unless @valid_lat_range.include?(lat)

      zip = row.field_by_id(:LOCATION_ZIP)
      raise "bad zip value \"Zipcode\": #{zip}" unless zip =~ @valid_zip_regexp

      rec = {
        :name => row.field_by_id(:SITE_NAME),
        :street => row.field_by_id(:LOCATION_ADDRESS),
        :city => row.field_by_id(:LOCATION_CITY),
        :state => "TX",
        :zip => zip,
        :geometry => Sequel.function(:MakePoint, lng, lat, 4326),
      }

      rec[:formatted] = rec[:name] + "\n" \
        + rec[:street] + "\n" \
        + rec[:city] + ", " + rec[:state] + " " + rec[:zip]

      rec_stored = @db[:voting_locations] \
        .filter{ST_Equals(:geometry, MakePoint(lng, lat, 4326))} \
        .first

      if rec_stored
        [:name, :street, :city, :state, :zip].each do |field|
          if rec_stored[field] != rec[field]
            @log.warn("make_location: \"#{field}\" value inconsistent with value in \"locations\" table");
            @log.warn("  record id = \"#{rec_stored[:id]}\"")
            @log.warn("  location name = \"#{rec_stored[:name]}\"") unless field == :name
            @log.warn("  stored #{field} = \"#{rec_stored[field]}\"")
            @log.warn("  new #{field}    = \"#{rec[field]}\"")
          end
        end
        return rec_stored
      end

      id = @db[:voting_locations].insert(rec)
      @db[:voting_locations][:id => id]
    end


    def make_schedule(hours)
      id = @db[:voting_schedules].insert({:formatted => format_schedule(hours).join("\n")})
      hours.each do |h|
        add_schedule_entry(id, h) unless is_closed_today(h)
      end
      @db[:voting_schedules][:id => id]
    end

    def append_schedule(id, hours)
      add_schedule_entry(id, hours)
      sched = @db[:voting_schedules].filter(:id => id)
      sched.update(:formatted => sched.get(:formatted) + "\n" + format_schedule_line(hours))
    end

    def add_schedule_entry(id, h)
      raise "bad schedule range: #{h}" if h.first >= h.last || h.first.yday != h.last.yday || h.first.year != h.last.year
      @db[:voting_schedule_entries] << {
        :schedule_id => id,
        :opens => h.first,
        :closes => h.last,
      }
      id
    end


    def load_eday_places(infile, hours)
      @log.info("load_eday_places: loading \"#{infile}\" ...")

      # Create schedule record for election day.
      schedule = make_schedule([hours])

      CSV.foreach(infile, :headers => true) do |row|

        cleanup_row(row)

        p0 = row.field_by_id(:PCT).to_i
        raise "failed to parse precinct from: #{row}" if p0 == 0
        precincts = [p0]

        location = make_location(row)

        notes = nil
        unless row.field_by_id(:COMBINED_PCTS, :empty_ok => true).empty?
          precincts += row.field_by_id(:COMBINED_PCTS).split(/[,:]/).map {|s| s.to_i}
          notes = "Combined precincts " + precincts.sort.join(", ")
        end

	(@explode_combined_precincts ? precincts : [p0]).each do |precinct|
          @db[:voting_places] << {
            :place_type => "ELECTION_DAY",
            :title => "Precinct #{precinct}",
            :precinct => precinct,
            :location_id => location[:id],
            :schedule_id => schedule[:id],
            :notes => notes,
          }
        end
      end
    end


    def load_evfixed_places(infile, hours_by_code)
      @log.info("load_evfixed_places: loading \"#{infile}\" ...")

      # Create schedule records and formatted displays for early voting schedules.
      schedule_by_code = {}
      hours_by_code.each do |code, hours|
        schedule_by_code[code] = make_schedule(hours)
      end

      CSV.foreach(infile, :headers => true) do |row|

        cleanup_row(row)

        # There are a number of rows with site names such as "Mobile 1"
        # with no data.
        next if row.field_by_id(:SITE_NAME) =~ /^Mobile/ && row.field_by_id(:SCHEDULE_CODE, :empty_ok => true).empty?

        location = make_location(row)

        sc1 = row.field_by_id(:SCHEDULE_CODE)
        sc2 = sc1 + "|" + row.field_by_id(:SITE_NAME)
        schedule = if schedule_by_code.has_key?(sc1)
          schedule_by_code[sc1]
        elsif schedule_by_code.has_key?(sc2)
          schedule_by_code[sc2]
        else
          raise "unknown schedule code \"#{sc1}\" (also tried \"#{sc2}\"): #{row}" unless schedule
        end

        @db[:voting_places] << {
          :place_type => "EARLY_FIXED",
          :title => "Early Voting Location",
          :location_id => location[:id],
          :schedule_id => schedule[:id],
          :notes => nil,
        }

      end
    end


    def load_evmobile_places(infile)
      @log.info("load_evmobile_places: loading \"#{infile}\" ...")

      CSV.foreach(infile, :headers => true) do |row|

        cleanup_row(row)

        location = make_location(row)

        hours = get_datetimes(row)

        place = @db[:voting_places] \
          .filter(:place_type => "EARLY_MOBILE") \
          .filter(:location_id => location[:id]) \
          .limit(1)

        if place.empty?
          schedule = make_schedule([hours])

          @db[:voting_places] << {
            :place_type => "EARLY_MOBILE",
            :title => "Mobile Early Voting Location",
            :location_id => location[:id],
            :schedule_id => schedule[:id],
            :notes => nil,
          }
        else
          append_schedule(place.get(:schedule_id), hours)
        end

      end

    end


  end
end


# Add #cleanup methods used by VoteATX::VotingPlacesLoader#cleanup_row.

class String
  def cleanup
    strip
  end
end

class Array
  def cleanup
    map {|e| e.cleanup}
  end
end

class NilClass
  def cleanup
    nil
  end
end

