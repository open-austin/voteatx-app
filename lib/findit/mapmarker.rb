module FindIt
  class MapMarker
    
    attr_accessor :url
    attr_accessor :height
    attr_accessor :width
    
    def initialize(url, params = {})
      raise("required parameter \":height\"  missing") unless params.has_key?(:height)
      raise("required parameter \":width\"  missing") unless params.has_key?(:width)
      @url = url
      @height = params[:height].to_i
      @width = params[:width].to_i
    end
    
    def to_h
      {
        :url => @url,
        :height => @height,
        :width => @width,
      }
    end
    
  end # class MapMarker
end # module FindIt