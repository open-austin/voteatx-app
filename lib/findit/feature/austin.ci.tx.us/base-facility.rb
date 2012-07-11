require 'findit/base-feature'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      #
      # The City of Austin "facilities" GIS dataset contains multiple features
      # of interest. This base class contains the database handling functions.
      # The derived classes contain the code for the specific feature.
      #
      class BaseFacility < FindIt::BaseFeature
                
        def self.closest_facility(fac_title, fac_type, origin)

          sth = DB.execute(%q{SELECT *,
            ST_X(ST_Transform(the_geom, 4326)) AS longitude,
            ST_Y(ST_Transform(the_geom, 4326)) AS latitude,
            ST_Distance(ST_Transform(the_geom, 4326), ST_SetSRID(ST_Point(?, ?), 4326)) AS distance
            FROM austin_ci_tx_us_facilities
            WHERE facility = ?
            ORDER BY distance ASC
            LIMIT 1
          }, origin.lng, origin.lat, fac_type)
          rec = sth.fetch
          sth.finish

          return nil unless rec  
          
          new(Location.new(rec[:latitude], rec[:longitude], :DEG),
            :title => fac_title,
            :name => rec[:name].capitalize_words,
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