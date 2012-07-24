require 'findit'
require 'findit/local/austin.ci.tx.us/feature/abstract-facility'

module FindIt
  module Feature
    module Austin_CI_TX_US
      class PostOffice < FindIt::Feature::Austin_CI_TX_US::AbstractFacility        
        @facility_title = "Closest post office"
        @facility_type = "POST OFFICE"
        @type = :POST_OFFICE
        @marker = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/ms/micons/postoffice-us.png",
          :height => 32, :width => 32).freeze
        @marker_shadow =  FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/ms/micons/postoffice-us.shadow.png",
          :height => 32, :width => 59).freeze
      end
    end
  end
end