require 'json'

module FindIt
  module Asset
    class MapRegion
      
      attr_reader :coordinates
      attr_accessor :stroke_color
      attr_accessor :stroke_opacity
      attr_accessor :stroke_weight
      attr_accessor :fill_color
      attr_accessor :fill_opacity
      
      def initialize(regionJSON, opts = {})
        region = JSON.parse(regionJSON)
        raise "region is not a GeoJSON polygon" unless region["type"] == "Polygon"
        raise "region is missing coordinates list" unless region["coordinates"]
        @coordinates = region["coordinates"].first
        @stroke_color = opts[:stroke_color] || opts[:color]
        @stroke_opacity = opts[:stroke_opacity]
        @stroke_weight = opts[:stroke_weight]
        @fill_color = opts[:fill_color] || opts[:color]
        @fill_opacity = opts[:fill_opacity]
      end
      
      def to_h
        ret = {:coordinates => @coordinates}
        ret[:stroke_color] = @stroke_color if @stroke_color
        ret[:stroke_opacity] = @stroke_opacity if @stroke_opacity
        ret[:stroke_weight] = @stroke_weight if @stroke_weight
        ret[:fill_color] = @fill_color if @fill_color
        ret[:fill_opacity] = @fill_opacity if @fill_opacity
        ret.freeze
      end
        
    end # class MapRegion        
  end # module Asset
end # module FindIt