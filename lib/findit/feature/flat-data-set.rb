require 'csv'

module FindIt
  module Feature
    
    # A data set stored in a CSV flat file.
    #
    # The data set for an associated feature is stored in a
    # data subdirectory.
    #
    # For instance, the feature described by:
    #
    #   lib/findit/feature/austin.ci.tx.us/fire-station.rb
    #
    # Uses the data set stored in:
    #
    #   lib/findit/feature/austin.ci.tx.us/data/fire-stations/Austin_Fire_Stations.csv
    #
    # This class makes it easy for FindIt::Feature::Austin_CI_TX_US::FireStation
    # to access the data.
    #
    class FlatDataSet
      
      # Locate an external data file for an associated feature.
      #
      # Parameters:
      #
      # * caller -- The full pathname of the file containing
      #   the calling code, i.e. <tt>__FILE__</tt>
      #
      # * dir -- The subdirectory for the data file.
      #
      # * file -- The filename of the data file.
      #
      # Returns: The full pathname (String).
      #
      # For example:
      #
      #   FindIt::Feature::FlatDataSet.path(__FILE__, "fire-stations", "Austin_Fire_Stations.csv")
      #
      # could be used by <i>fire-station.rb</i> to locate the fire stations data set.
      #
      def self.path(caller, dir, file)          
        File.dirname(caller) + "/data/" + dir + "/" + file
      end
      
      
      # Create a new FlatDataSet from a CSV data set.
      #
      # Parameters <i>caller</i>, <i>dir</i>, and <i>file</i> are
      # passed to self.path method.
      #
      # The <i>options</i> are passed to the ::FlatDataSet constructor.
      #
      # The block is called for each row of the data set. It
      # is passed a CSV::Row object. The block should return a
      # hash of values, which is added to the list.
      #
      # Example:
      #
      #   @police_stations = FindIt::Feature::FlatDataSet.load(__FILE__, "police-stations", "Austin_Police_Stations.csv") do |row|
      #     lng = row["X"].to_f
      #     lat = row["Y"].to_f
      #     {       
      #       :name => row["STATION NAME"],
      #       :address => row["ADDRESS"],
      #       :location => FindIt::Location.new(lat, lng, :DEG),
      #     }
      #   end
      #
      def self.load(caller, dir, file, options = {})
        pn = path(caller, dir, file)
        ds = []          
        CSV.foreach(pn, :headers => true) do |row|
          rec = yield(row)
          ds << rec.freeze if rec
        end
        new(ds, options)
      end

      
      # Construct a new FlatDataSet instance.
      #
      # Arguments:
      # * dataset - The data set, stored as a list of hashes.
      # * options:
      #   * :location - Field that contains a location. (default: ":location")
      #   * :index - Field that should be indexed. (default: none)
      #
      # The ":location" option specifies a field that contains a  FindIt::Location
      # value. The closest() method can then be used to obtain the row that
      # is closest to a given location.
      #
      # The ":index" option specifies a field that should be indexed for quick
      # lookup. The [] method can then be used to retrieve a row by index value.
      #
      #
      def initialize(dataset, options = {})
        @dataset = dataset.freeze
        
        @location_field = options[:location] || :location
          
        @dataset_indexed = {}
        @index_field = options[:index]
        if @index_field
          @dataset.each do |rec|
            key = rec[@index_field]
            @dataset_indexed[key] = rec
          end
        end
      end
      
      
      # Lookup an entry by indexed value.
      #
      # Returns nil if the entry is not found or if the data set was not indexed.
      #
      # A data set is indexed by using the ":index" initialization option.
      #
      def [](key)
        @dataset_indexed[key]
      end          
      
      
      # Find the entry in the data set that is closest to the indicated location.
      #
      # Arguments:
      # * location - A FindIt::Location instance.
      #
      # Returns a hash that contains the selected record from the data set.
      # A field named ":distance" will be added to the result, that contains
      # the distance to the closest item (in miles).
      #
      # The location of a row is identified by the ":loocation" initialization
      # option.
      #        
      def closest(location)    
        feature = nil
        distance = nil          
        @dataset.each do |f|
          d = location.distance(f[@location_field])
          if distance.nil? || d < distance
            feature = f
            distance = d
          end            
        end
        feature.merge(:distance => distance)
      end
      
    end # module FlatDataSet
  end # module Feature
end # module FindIt

