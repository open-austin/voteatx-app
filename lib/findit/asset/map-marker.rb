require 'findit/asset/image'

module FindIt
  module Asset    
    class MapMarker
      
      DEFAULT_MARKER_HEIGHT = 32
      DEFAULT_MARKER_WIDTH = 32
      DEFAULT_SHADOW_WIDTH = 59
      
      attr_reader :marker
      attr_reader :shadow
    
      #
      # Construct a new FindIt::Asset::MapMarker.
      #
      # A MapMarker is a graphic image (and an optional shadow image to provide 3D effect) to
      # identify a point on a map.
      #
      # Parameters:
      #
      # * url -- The URL of the marker image file.
      #
      # * params -- Parameters for the marker.
      #
      # Returns: A FindIt::Asset::MapMarker instance.
      #
      # The following <i>params</i> are supported.
      #
      # * :height => INTEGER -- Height of the image in pixels. (default: DEFAULT_MARKER_HEIGHT)
      # * :width => INTEGER -- Width of the image in pixels. (default: DEFAULT_MARKER_WIDTH)
      # * :shadow => URL (default: none)
      # * :height_shadow => INTEGER (default: same height as marker)
      # * :width_shadow => INTEGER (default: DEFAULT_SHADOW_WIDTH)
      #
      # The :shadow URL can either be a full URL, or just a filename. If just a filename
      # is specified then the URL of the marker image is used as the base URL.
      #
      # Example:
      #
      #   m = FindIt::Asset::MapMarker.new(
      #     "http://maps.google.com/mapfiles/kml/pal2/icon0.png",
      #     :shadow => "icon0s.png")
      #
      # In this example, the URL for the marker shadow image will be:
      #
      #   http://maps.google.com/mapfiles/kml/pal2/icon0s.png"
      #                 
      def initialize(url, params = {})
        height = params[:height] || DEFAULT_MARKER_HEIGHT
        width = params[:width] || DEFAULT_MARKER_WIDTH
        @marker = FindIt::Asset::Image.new(url, :height => height, :width => width)
        
        @shadow = if params[:shadow]
          url_shadow = params[:shadow]
          if url_shadow !~ %r{/}
            url_shadow.insert(0, url.sub(%r{[^/]*$}, ""))
          end
          height_shadow = params[:height_shadow] || height
          width_shadow = params[:width_shadow] || DEFAULT_SHADOW_WIDTH
          FindIt::Asset::Image.new(url_shadow, :height => height_shadow, :width => width_shadow)
        else
          nil
        end
      end
      
      def to_h
        h = {}
        h[:marker] = @marker.to_h
        h[:shadow] = @shadow.to_h if @shadow
        h.freeze
      end      

    end # class MapMarker
  end # module Asset    
end # module FindIt