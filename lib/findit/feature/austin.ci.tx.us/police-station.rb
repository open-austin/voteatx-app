require 'findit'
require 'findit/feature/flat-data-set'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      # Implementation of FindIt::BaseFeature to represent Police stations in Austin, TX.
      class PoliceStation < FindIt::BaseFeature

        @type = :POLICE_STATION
        
        @marker = FindIt::Asset::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal2/icon8.png",
          :shadow => "icon8s.png")
                            
        @police_stations = FindIt::Feature::FlatDataSet.load(__FILE__, "police-stations", "Austin_Police_Stations.csv") do |row|

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
          
          {        
            :name => row["STATION NAME"],
            :street => street,
            :city => "Austin",
            :state => "TX",
            :location => FindIt::Location.new(lat, lng, :DEG),
          }
         
        end # load_csv_data_set_with_location


        def self.closest(origin)

          feature = @police_stations.closest(origin)
          
          return nil unless feature         

          new(feature[:location],
            :title => "Closest police station",
            :name => feature[:name],
            :address => feature[:street],
            :city =>  feature[:city],
            :state => feature[:state],
            :zip => feature[:zip],
            :distance => feature[:distance]
          )
        end
        
        
      end
    end
  end
end
