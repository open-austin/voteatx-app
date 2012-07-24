require 'findit'
require 'csv'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      # Implementation of FindIt::BaseFeature to represent fire stations in Austin, TX.
      class FireStation < FindIt::BaseFeature

        @type = :FIRE_STATION
        
        @marker = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal2/icon0.png",
          :height => 32, :width => 32).freeze
          
        @marker_shadow = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal2/icon0s.png",
          :height => 32, :width => 59).freeze                  
               
        DATAFILE = self.datafile(__FILE__, "fire-stations", "Austin_Fire_Stations.csv")
        
        def self.load_dataset
          
          ds = []
            
          CSV.foreach(DATAFILE, :headers => true) do |row|
            
            # Example Row:
            #
            #  <CSV::Row
            #    "Name":"FS0045"
            #    "Jurisdiction Name":"AFD"
            #    "Y":"30.482101"
            #    "X":"-97.766185"
            #    "Location 1":"9421 Spectrum Dr\nAUSTIN, TX 78717\n(30.482101, -97.766185)">
            #
            
            lng = row["X"].to_f
            lat = row["Y"].to_f
            street, citystatezip = row["Location 1"].split("\n")
            m = citystatezip.strip.gsub(/\s+/, " ").match(/^(.*), (.*) ([-0-9]+)$/)
            
            ds << {        
              :name => "Fire Station " + row["Name"].sub(/^FS0*/, ""),
              :street => street,
              :city => m[1].capitalize_words,
              :state => m[2],
              :zip => m[3],
              :location => FindIt::Location.new(lat, lng, :DEG),
            }
           
          end
          
          return ds
        end
        
        DATASET = load_dataset.freeze     
        

        def self.closest(origin)
          
          feature = nil
          distance = nil
          
          DATASET.each do |f|
            d = origin.distance(f[:location])
            if distance.nil? || d < distance
              feature = f
              distance = d
            end            
          end
          
          return nil unless feature         

          new(feature[:location],
            :title => "Closest fire station",
            :name => feature[:name],
            :address => feature[:street],
            :city => feature[:city],
            :state => feature[:state],
            :zip => feature[:zip],
            :distance => distance
          )
        end
        
        
      end
    end
  end
end
