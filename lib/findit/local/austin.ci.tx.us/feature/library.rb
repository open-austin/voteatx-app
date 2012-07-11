require 'findit'
require 'findit/local/austin.ci.tx.us/feature/base-facility'

module FindIt
  module Feature
    module Austin_CI_TX_US      

      # Implementation of FindIt::Feature::Austin_CI_TX_US::BaseFacility to represent libraries in Austin, TX.
      class Library < FindIt::Feature::Austin_CI_TX_US::BaseFacility  
        
        def self.facility_title
          "Closest library"
        end   
        
        def self.facility_type
          "LIBRARY"
        end                  

        def self.type
          :LIBRARY
        end
        
        MARKER = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon56.png",
          :height => 32, :width => 32).freeze
          
        def self.marker
          MARKER
        end  
        
        MARKER_SHADOW = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon56s.png",
          :height => 32, :width => 59).freeze                   
        
        def self.marker_shadow
          MARKER_SHADOW
        end 
              
      end
    end
  end
end