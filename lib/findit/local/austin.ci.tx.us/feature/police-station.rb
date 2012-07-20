require 'findit'
require 'csv'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      # Implementation of FindIt::BaseFeature to represent Police stations in Austin, TX.
      class PoliceStation < FindIt::BaseFeature
        
        DATAFILE = self.datafile(__FILE__, "police-stations", "Austin_Police_Stations.csv")
        
        def self.load_dataset
          
          ds = []
            
          CSV.foreach(DATAFILE, :headers => true) do |row|
            
            # Example Row:
            #
            #   <CSV::Row
            #     "STATION_NAME":"Main Headquarters"
            #     "X":"-97.735070"
            #     "Y":"30.267574"
            #     "Location":"715 E. 8th St\n(30.267574, -97.735070)">

            
            lng = row["X"].to_f
            lat = row["Y"].to_f
            street = row["Location"].split("\n").first
            
            ds << {        
              :name => row["STATION NAME"],
              :street => street,
              :city => "Austin",
              :state => "TX",
              :location => FindIt::Location.new(lat, lng, :DEG),
            }
           
          end
          
          return ds
        end
        
        DATASET = load_dataset.freeze         

        def self.type
          :POLICE_STATION
        end
        
        MARKER = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal2/icon8.png",
          :height => 32, :width => 32).freeze
          
        def self.marker
          MARKER
        end  
        
        MARKER_SHADOW = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal2/icon8s.png",
          :height => 32, :width => 59).freeze                   
        
        def self.marker_shadow
          MARKER_SHADOW
        end        

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
            :title => "Closest police station",
            :name => feature[:name],
            :address => feature[:street],
            :city =>  feature[:city],
            :state => feature[:state],
            :zip => feature[:zip],
            :distance => distance
          )
        end
        
        
      end
    end
  end
end
