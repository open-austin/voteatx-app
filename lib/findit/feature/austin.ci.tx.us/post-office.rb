require 'findit/feature/austin.ci.tx.us/base-facility'

module FindIt
  module Feature
    module Austin_CI_TX_US
      class PostOffice < FindIt::Feature::Austin_CI_TX_US::BaseFacility
      
        def self.closest(origin)
          self.closest_facility("Closest post office", "POST OFFICE", origin)
        end   
                    
        def self.type
           :POST_OFFICE
        end
                  
        MARKER = FindIt::Feature::MapMarker.new(
            "http://maps.google.com/mapfiles/ms/micons/postoffice-us.png",
            :height => 32, :width => 32).freeze
            
        def self.marker
          MARKER
        end  
        
        MARKER_SHADOW = FindIt::Feature::MapMarker.new(
            "http://maps.google.com/mapfiles/ms/micons/postoffice-us.shadow.png",
            :height => 32, :width => 59).freeze
        
        def self.marker_shadow
          MARKER_SHADOW
        end  
                      
      end
    end
  end
end