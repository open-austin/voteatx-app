module FindIt
  
  #
  # A graphic icon to be placed on the map as a marker.
  #
  # For a list of map icons available at Google, see:
  # https://sites.google.com/site/gmapsdevelopment/
  #
  class MapMarker
    
    attr_reader :url
    attr_reader :height
    attr_reader :width
    
    #
    # Construct a new MapMarker.
    #
    # Parameters:
    #
    # * url -- The URL of the graphic.
    #
    # * params -- Parameters for the marker.
    #
    # Returns: A FindIt::MapMarker instance.
    #
    # The following <i>params</i> are supported.
    #
    # * :height => <i>Integer</i> -- Height of the graphic in pixels. (required)
    # * :width => <i>Integer</i> -- Width of the graphic in pixels. (required)
    #
    def initialize(url, params = {})
      raise("required parameter \":height\"  missing") unless params.has_key?(:height)
      raise("required parameter \":width\"  missing") unless params.has_key?(:width)
      @url = url
      @height = params[:height].to_i
      @width = params[:width].to_i
    end
    
    # Produce a Hash that represents the MapMarker values.
    def to_h
      {
        :url => @url,
        :height => @height,
        :width => @width,
      }.freeze
    end
    
  end # class MapMarker
end # module FindIt