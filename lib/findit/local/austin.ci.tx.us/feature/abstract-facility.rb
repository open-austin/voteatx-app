require 'findit'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      
      #
      # Abstract class derived from FindIt::BaseFeature to represent a variety
      # of features found in the City of Austin "facilities" GIS dataset.
      #
      class AbstractFacility < FindIt::BaseFeature
        
        @facility_title = nil
        @facility_type = nil
        
        def self.facility_title
          @facility_title
        end
        
        def self.facility_type
          @facility_type
        end
        
#        #
#        # A title for this facility, such as "Closest library", that is used
#        # as the <i>title</i> parameter when creating the Feature instance.
#        #
#        # <b>This is an abstract method that must be overridden in the derived class.</b>
#        #
#        def self.facility_title    
#          raise NotImplementedError, "abstract method \"self.facility_title\" must be overridden"
#        end   
#        
#        
#        #
#        # A value to match against the "facility" field in the database lookup,
#        # such as "LIBRARY".
#        #
#        # <b>This is an abstract method that must be overridden in the derived class.</b>
#        #
#        def self.facility_type
#          raise NotImplementedError, "abstract method \"self.facility_type\" must be overridden"
#        end    
        
        
        #
        # See: FindIt::BaseFeature::closest
        #
        def self.closest(origin)

          sth = DB.execute(%q{SELECT *,
            ST_X(ST_Transform(the_geom, 4326)) AS longitude,
            ST_Y(ST_Transform(the_geom, 4326)) AS latitude,
            ST_Distance(ST_Transform(the_geom, 4326), ST_SetSRID(ST_Point(?, ?), 4326)) AS distance
            FROM austin_ci_tx_us_facilities
            WHERE facility = ?
            ORDER BY distance ASC
            LIMIT 1
          }, origin.lng, origin.lat, self.facility_type)
          rec = sth.fetch
          sth.finish

          return nil unless rec  
          
          new(FindIt::Location.new(rec[:latitude], rec[:longitude], :DEG),
            :title => self.facility_title,
            :name => rec[:name].capitalize_words,
            :address => rec[:address].capitalize_words,
            :city => "Austin",
            :state => "TX",
            :origin => origin
          )
          
        end # self.closest
        
      end # class AbstractFacility     
      
    end # module Austin_CI_TX_US
  end # module Feature    
end # module FindIt

