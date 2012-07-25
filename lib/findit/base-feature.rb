module FindIt
   
  # Abstract class for a map feature.
  #
  # To implement a feature, the derived class must:
  #
  # * Either define <i>@type</i> class instance variable or override <i>self.type</i> method.
  # * Either define <i>@marker</i> class instance variable or override <i>self.marker</i> method.
  # * Either define <i>\@marker_shadow</i> class instance variable or override <i>self.marker_shadow</i> method.
  # * Override <i>self.closest</i> method.
  #
  # Example:
  #
  #   class Library < FindIt::BaseFeature
  #     @type = :LIBRARY
  #     @marker = FindIt::MapMarker.new(
  #       "http://maps.google.com/mapfiles/kml/pal3/icon56.png",
  #       :height => 32, :width => 32).freeze
  #     @marker_shadow = FindIt::MapMarker.new(
  #       "http://maps.google.com/mapfiles/kml/pal3/icon56s.png",
  #       :height => 32, :width => 59).freeze
  #     def self.closest(loc)
  #          . 
  #          . 
  #          . 
  #     end
  #   end
  #
  class BaseFeature
    
    # A FindIt::Location instance that provides the geographical
    # location (latitude, longitude) of this feature.
    # This value is required and will always be defined.
    attr_reader :location
    
    # A title for this feature, such as "Closest library".
    # This value is required and will always be defined.
    attr_reader :title
    
    # The name of this feature, such as "Grouch Marx Middle School".
    # This value is optional and may be nil.
    attr_reader :name
    
    # The street address of this feature.
    # This value is required and will always be defined.
    attr_reader :address
    
    # The city portion of the address of this feature.
    # This value is required and will always be defined.
    attr_reader :city
    
    # The state portion of the address of this feature.
    # This value is required and will always be defined.
    attr_reader :state
    
    # The postal code portion of the address of this feature.
    # This value is optional and may be nil.
    attr_reader :zip
    
    # A URL to associate with this feature, such as a home page.
    # This value is optional and may be nil.
    attr_accessor :link
    
    # An optional note with additional information about this feature.
    # This value is optional and may be nil.
    attr_accessor :note
    
    # A Float value containing the distance (in miles) from the
    # origin point to this feature.
    attr_reader :distance
    
    
    #
    # Construct a new feature.
    #
    # Parameters:
    #
    # * location -- A FindIt::Location instance with the location 
    #   of this feature.
    #
    # * params -- Parameters to initialize feature attributes. See
    #   the description of the FindIt::BaseFeature attributes for
    #   details on parameter values.
    #
    # Returns: A FindIt::BaseFeature instance.
    #
    # The following parameters are required:
    #
    # * :title => String
    # * :address => String
    # * :city => String
    # * :state => String
    #
    # One of the following parameters must be specified.
    #
    # * :distance => Numeric
    # * :origin => FindIt::Location
    #
    # If both are specified, the <tt>:distance</tt> takes precedence.
    # The <tt>:origin</tt> is used only to calculate distance; the coordinate itself is not saved.
    #
    # The following parameters are optional.
    #
    # * :name => String
    # * :zip => String
    # * :link => String
    # * :note => String
    #
    def initialize(location, params = {})
      [:title, :address, :city, :state].each do |p|
        raise "required parameter \":#{p}\" not specified" unless params.has_key?(p)
      end
      @location = location
      @title = params[:title]
      @name = params[:name] if params.has_key?(:name)
      @address = params[:address]
      @city = params[:city]
      @state = params[:state]
      @zip = params[:zip] if params.has_key?(:zip)
      @link = params[:link] if params.has_key?(:link)
      @note = params[:note] if params.has_key?(:note)
      @distance = if params.has_key?(:distance)
        params[:distance]
      elsif params.has_key?(:origin)
        location.distance(params[:origin])
      else
        raise "must specify either \":distance\" or \":origin\" parameter"
      end
    end

    
    #
    # Locate the feature closest to the origin.
    #
    # <b>This is an abstract method that must be overridden in the derived class.</b>
    #
    # Parameter:
    #
    # * origin -- A FindIt::Location instance that is the origin point
    #   for the search.
    #
    # Returns: The instance of this feature that is closest to the
    # origin point (FindIt::BaseFeature).
    #
    def self.closest(origin)
      raise NotImplementedError, "abstract method \"self.closest\" must be overridden"
    end    
    
    
    #
    # The feature type.
    #
    # Returns: A symbol that indicates the feature type, such
    # as <tt>:FIRE_STATION</tt> or <tt>:LIBRARY</tt>.
    # 
    # The default implementation returns the value of the
    # <i>@type</i> class instance variable. A derived class
    # should either initialize that variable or override this
    # method.
    #
    def self.type
      raise NameError, "class instance parameter \"type\" not initialized for class \"#{self.name}\"" unless @type
      @type
    end
    
    
    #
    # The map marker graphic for this feature.
    #
    # Returns: The graphic that should be used to identify
    # this feature on a map (FindIt::MapMarker).
    #
    # The default implementation returns the value of the
    # <i>@marker</i> class instance variable. A derived class
    # should either initialize that variable or override this
    # method.
    #
    def self.marker
      raise NameError, "class instance parameter \"marker\" not initialized for class \"#{self.name}\"" unless @marker
      @marker
    end
    
    
    #
    # The map marker for this feature.
    #
    # Returns: The value from the class method <i>self.marker</i>.
    #
    # Typically all features of a given type will use the same
    # marker, which is what this default implementation provides.
    # If you wish to customize the marker within a feature class,
    # the implementing class can override this method.
    #
    def marker
      self.class.marker
    end
    
    
    #
    # The map marker shadow graphic for this feature.
    #
    # Returns: The graphic that should be used as a shadow graphic
    # under the map marker for this feature (FindIt::MapMarker).
    #
    # The default implementation returns the value of the
    # <i>@marker_shadow</i> class instance variable. A derived class
    # should either initialize that variable or override this
    # method.
    #
    def self.marker_shadow
      raise NameError, "class instance parameter \"marker_shadow\" not initialized for class \"#{self.name}\"" unless @marker_shadow
      @marker_shadow
    end
    
    #
    # The map marker shadow for this feature.
    #
    # Returns: The value from the class method <i>self.marker_shadow</i>.
    #
    # Typically all features of a given type will use the same
    # marker, which is what this default implementation provides.
    # If you wish to customize the marker within a feature class,
    # the implementing class can override this method.
    #
    def marker_shadow
      self.class.marker_shadow
    end
        
    
    #
    # A brief "hover" hint string to display for this feature.
    #
    # Returns: A plain text string, with HTML characters escaped.
    #
    def hint
      s = @title + ": " + (@name.empty? ? @address : @name)
      s.html_safe
    end
    
    
    #
    # Detail information on this feature, suitable for display in
    # a pop-up window.
    #
    # Returns: An HTML string.
    #
    def info
      result = []    
      result << "<b>" + @title.capitalize_words.html_safe + "</b>"
      result << @name.html_safe unless @name.empty?
      result << @address.html_safe
      
      s = @city + ", " + @state
      s += " " + @zip unless @zip.empty?
      result << s.html_safe
      
      result << @note.html_safe unless @note.empty?
      
      result << "%.1f mi away" % [@distance]
        
      unless @link.empty?
        result << "<a href=\"" + @link.html_safe + "\">more info ...</a>"
      end
      
      "<div class=\"findit-feature-info\">\n" + result.join("<br />\n") + "\n</div>"
    end
    

    # Produce a Hash that represents the feature values.
    def to_h
      {    
        :type => self.class.type,
        :title => @title,
        :name => @name,
        :address => @address,
        :city => @city,
        :state => @state,
        :zip => @zip,
        :link => @link,
        :note => @note,
        :latitude => @location.lat,
        :longitude => @location.lng,
        :distance => @distance,
        :hint => self.hint,
        :info => self.info,
        :marker => self.marker.to_h,
        :marker_shadow => self.marker_shadow.to_h,
      }
    end
    
  end
end