require 'findit'

module FindIt
  module Feature
    module Austin_CI_TX_US      

      # Implementation of FindIt::BaseFeature to represent moon towers in Austin, TX.
      class MoonTower < FindIt::BaseFeature
        
        @type = :MOON_TOWER
        
        @marker = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon40.png",
          :height => 32, :width => 32).freeze
          
        @marker_shadow = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon40s.png",
          :height => 32, :width => 59).freeze                   

        def self.closest(origin)

          sth = DB.execute(%q{SELECT *,
            ST_X(ST_Transform(the_geom, 4326)) AS longitude,
            ST_Y(ST_Transform(the_geom, 4326)) AS latitude,
            ST_Distance(ST_Transform(the_geom, 4326), ST_SetSRID(ST_Point(?, ?), 4326)) AS distance
            FROM austin_ci_tx_us_historical
            WHERE building_n = ?
            ORDER BY distance ASC
            LIMIT 1
          }, origin.lng, origin.lat, "MOONLIGHT TOWERS")
          rec = sth.fetch
          sth.finish

          return nil unless rec  
          
          new(FindIt::Location.new(rec[:latitude], rec[:longitude], :DEG),
            :title => "Closest moon tower",
            :address => rec[:address].capitalize_words,
            :city => "Austin",
            :state => "TX",
            :origin => origin
          )
        end
        
        
      end
    end
  end
end