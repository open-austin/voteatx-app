require 'findit'

module FindIt
  module Feature
    module Austin_CI_TX_US      

      class HistoricalFactory
        
        def self.create(db, type, options = {})
          klass = Class.new(AbstractHistorical)
          klass.instance_variable_set(:@db, db)
          klass.instance_variable_set(:@type, type)
          case type
            
          when :MOON_TOWER
            klass.instance_variable_set(:@marker, FindIt::MapMarker.new(
              "http://maps.google.com/mapfiles/kml/pal3/icon40.png",
              :height => 32, :width => 32))
            klass.instance_variable_set(:@marker_shadow, FindIt::MapMarker.new(
              "http://maps.google.com/mapfiles/kml/pal3/icon40s.png",
              :height => 32, :width => 59))
            klass.instance_variable_set(:@title, "Closest moon tower")
            klass.instance_variable_set(:@rectype, "MOONLIGHT TOWERS")            
            
          else
            raise "unknown historical type \"#{type}\""
            
          end
          
          klass          
        end # initialize
        
      end # class HistoricalFactory
      
      
      class AbstractHistorical < FindIt::BaseFeature
        
        @db = nil
        @title = nil
        @rectype = nil
                         

        def self.closest(origin)

          sth = @db.execute(%q{SELECT *,
            ST_X(ST_Transform(the_geom, 4326)) AS longitude,
            ST_Y(ST_Transform(the_geom, 4326)) AS latitude,
            ST_Distance(ST_Transform(the_geom, 4326), ST_SetSRID(ST_Point(?, ?), 4326)) AS distance
            FROM austin_ci_tx_us_historical
            WHERE building_n = ?
            ORDER BY distance ASC
            LIMIT 1
          }, origin.lng, origin.lat, @rectype)
          rec = sth.fetch
          sth.finish

          return nil unless rec  
          
          new(FindIt::Location.new(rec[:latitude], rec[:longitude], :DEG),
            :title => @title,
            :address => rec[:address].capitalize_words,
            :city => "Austin",
            :state => "TX",
            :origin => origin
          )
        end
        
        
      end # class AbstractHistorical
      
    end # module Austin_CI_TX_US
  end # module Feature
end # module FindIt