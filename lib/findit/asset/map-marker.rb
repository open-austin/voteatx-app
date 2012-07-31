require 'findit/asset/image'

module FindIt
  module Asset    
    class MapMarker
      
      DEFAULT_MARKER_HEIGHT = 32
      DEFAULT_MARKER_WIDTH = 32
      DEFAULT_SHADOW_WIDTH = 59
      
      attr_reader :marker
      attr_reader :marker_shadow
      
        def initialize(url, params = {})
          height = params[:height] || DEFAULT_MARKER_HEIGHT
          width = params[:width] || DEFAULT_MARKER_WIDTH
          @marker = FindIt::Asset::Image.new(url, :height => height, :width => width)
          if params[:shadow]
            url_shadow = params[:shadow]
            if url_shadow !~ %r{/}
              url_shadow.insert(0, url.sub(%r{[^/]*$}, ""))
            end
            height_shadow = params[:height_shadow] || height
            width_shadow = params[:width_shadow] || DEFAULT_SHADOW_WIDTH
            @marker_shadow = FindIt::Asset::Image.new(url_shadow, :height => height_shadow, :width => width_shadow)
          else
            @marker_shadow = nil
          end
        end
        
        def to_h
          h = {}
          h[:marker] = @marker.to_h
          h[:shadow] = @marker_shadow.to_h if @marker_shadow
          h.freeze
        end      

    end # class MapMarker
  end # module Asset    
end # module FindIt