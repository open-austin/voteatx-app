require 'csv'

module FindIt
  module Feature
    
    # A data set stored in a CSV flat file.
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
      # For example, given a file:
      #
      #   $LIBDIR/findit/feature/austin.ci.tx.us/fire-station.rb
      #
      # Making the following call:
      #
      #   self.path(__FILE__, "fire-stations", "Austin_Fire_Stations.csv")
      #
      # Would produce:
      #
      #   $LIBDIR/findit/local/austin.ci.tx.us/data/fire-stations/Austin_Fire_Stations.csv
      #
      def self.path(caller, dir, file)          
        File.dirname(caller) + "/data/" + dir + "/" + file
      end
      
      
      # Load a CSV data set into a list
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
      #   @police_stations = FindIt::Feature::FlatDataSet.load_csv(__FILE__, "police-stations", "Austin_Police_Stations.csv") do |row|
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

      
      # Arguments:
      # * dataset - The data set, stored as a list of hashes.
      # * options
      #   * :location - Name of a field that contains a FindIt::Location
      #     value. This location is used by the closest() search. (default: ":location")
      #   * :index - If specified, a field name. The data set will be indexed
      #     on this field, for lookup via []. (default: none)
      #
      def initialize(dataset, options = {})
        @dataset = dataset
        
        @location_field = options[:location] || :location
          
        @dataset_indexed = {}
        @index_field = options[:index]
        if @index_field
          @dataset.each do |rec|
            @dataset_indexed[rec[@index_field]] = rec
          end
        end
      end
      
      
      # Lookup an entry by indexed value.
      #
      # Returns nil if the entry is not found or if the data set was not indexed.
      #
      # 
      #
      def [](key)
        @dataset_indexed[key]
      end          
      
      
      # Find the entry in the data set that is closest to the indicated location.
      #
      # Returns a hash that contains the selected record from the data set.
      # A field named ":distance" will be added to the result, that contains
      # the distance to the closest item (in miles).
      #
      # Arguments:
      # * location - A FindIt::Location instance.
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

