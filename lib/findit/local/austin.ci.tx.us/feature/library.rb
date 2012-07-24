require 'findit'
require 'findit/local/austin.ci.tx.us/feature/abstract-facility'

module FindIt
  module Feature
    module Austin_CI_TX_US
      class Library < FindIt::Feature::Austin_CI_TX_US::AbstractFacility 
        @facility_title = "Closest library"
        @facility_type = "LIBRARY"
        @type = :LIBRARY
        @marker = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon56.png",
          :height => 32, :width => 32).freeze
        @marker_shadow = FindIt::MapMarker.new(
          "http://maps.google.com/mapfiles/kml/pal3/icon56s.png",
          :height => 32, :width => 59).freeze 
      end
    end
  end
end