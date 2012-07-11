require 'findit/base-feature'
require 'findit/location'
require 'findit/mapmarker'

module FindIt
  module Feature
    module Austin_CI_TX_US
      class MoonTower < FindIt::BaseFeature
        
        def self.type
          :MOON_TOWER
        end
        
        MARKER = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon40.png",
          :height => 32, :width => 32).freeze
          
        def self.marker
          MARKER
        end  
        
        MARKER_SHADOW = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon40s.png",
          :height => 32, :width => 59).freeze                   
        
        def self.marker_shadow
          MARKER_SHADOW
        end        

        def self.closest(origin)

          sth = DB.execute(%q{SELECT *,
            ST_X(ST_Transform(the_geom, 4326)) AS longitude,
            ST_Y(ST_Transform(the_geom, 4326)) AS latitude,
            ST_Distance(ST_Transform(the_geom, 4326), ST_SetSRID(ST_Point(?, ?), 4326)) AS distance
            FROM austin_ci_tx_us_historical
            WHERE building_n = 'MOONLIGHT TOWERS'
            ORDER BY distance ASC
            LIMIT 1
          }, origin.lng, origin.lat)
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