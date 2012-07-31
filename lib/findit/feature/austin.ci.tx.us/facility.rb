require 'findit'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      class FacilityFactory
        
        def self.create(db, type, options = {})
          klass = Class.new(AbstractFacility)
          klass.instance_variable_set(:@db, db)
          klass.instance_variable_set(:@type, type)
          case type
            
          when :POST_OFFICE
            klass.instance_variable_set(:@marker, FindIt::Asset::MapMarker.new(
              "http://maps.google.com/mapfiles/ms/micons/postoffice-us.png", :shadow => "postoffice-us.shadow.png"))
            klass.instance_variable_set(:@facility_title, "Closest post office")
            klass.instance_variable_set(:@facility_type, "POST OFFICE")
            
          when :LIBRARY
            klass.instance_variable_set(:@marker, FindIt::Asset::MapMarker.new(
              "http://maps.google.com/mapfiles/kml/pal3/icon56.png", :shadow => "icon56s.png"))
            klass.instance_variable_set(:@facility_title, "Closest library")
            klass.instance_variable_set(:@facility_type, "LIBRARY")
            
          else
            raise "unknown facility type \"#{type}\""
            
          end
          
          klass          
        end # initialize
        
      end # class FacilityFactory
      
      
      #
      # Abstract class derived from FindIt::BaseFeature to represent a variety
      # of features found in the City of Austin "facilities" GIS dataset.
      #
      class AbstractFacility < FindIt::BaseFeature
        
        @db = nil
        
        @facility_title = nil
        
        @facility_type = nil
        
        def self.facility_title
          raise NameError, "class instance parameter \"facility_title\" not initialized for class \"#{self.name}\"" unless @facility_title
          @facility_title
        end
        
        def self.facility_type
          raise NameError, "class instance parameter \"facility_type\" not initialized for class \"#{self.name}\"" unless @facility_type
          @facility_type
        end
        
        
        #
        # See: FindIt::BaseFeature::closest
        #
        def self.closest(origin)

          sth = @db.execute(%q{SELECT *,
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

