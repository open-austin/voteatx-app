module FindIt
  module Asset    
    class Image      
    
    attr_reader :url
    attr_reader :height
    attr_reader :width
    
      #
      # Construct a new FindIt::Asset::Image.
      #
      # Parameters:
      #
      # * url -- The URL of the image file.
      #
      # * params -- Parameters for the image.
      #
      # Returns: A FindIt::Asset::Image instance.
      #
      # The following <i>params</i> are supported.
      #
      # * :height => INTEGER -- Height of the image in pixels. (required)
      # * :width => INTEGER -- Width of the image in pixels. (required)
      #
      def initialize(url, params = {})
        raise("required parameter \":height\"  missing") unless params.has_key?(:height)
        raise("required parameter \":width\"  missing") unless params.has_key?(:width)
        @url = url
        @height = params[:height].to_i
        @width = params[:width].to_i
      end
      
      # Produce a Hash that represents the Image values.
      def to_h
        {
          :url => @url,
          :height => @height,
          :width => @width,
        }.freeze
      end
  
    end # class Image
  end # module Asset    
end # module FindIt