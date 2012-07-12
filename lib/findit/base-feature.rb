module FindIt
   
  # Abstract class for a map feature.
  #
  # To implement a feature, the derived class must override the
  # following methods:
  #
  # * self.type
  # * self.marker
  # * self.marker_shadow
  # * self.closest
  #
  class BaseFeature
    
    #
    # Locate an external datafile for this feature.
    #
    # Parameters:
    #
    # * caller -- The full pathname of the file containing
    #   the calling code, i.e. <tt>__FILE__</tt>
    #
    # * dir -- The subdirectory for the datafile.
    #
    # * file -- The filename of the datafile.
    #
    # Returns: The full pathname (String).
    #
    # For example, given a file:
    #
    #   $LIBDIR/findit/local/austin.ci.tx.us/feature/fire-station.rb
    #
    # Making the following call:
    #
    #   self.datafile(__FILE__, "fire-stations", "Austin_Fire_Stations.csv")
    #
    # Would produce:
    #
    #   $LIBDIR/findit/local/austin.ci.tx.us/data/fire-stations/Austin_Fire_Stations.csv
    #
    def self.datafile(caller, dir, file)          
      File.dirname(caller) + "/../data/" + dir + "/" + file
    end

    
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
      raise "abstract method \"self.closest\" must be overridden"
    end    
    
    
    #
    # The feature type.
    #
    # <b>This is an abstract method that must be overridden in the derived class.</b>
    #
    # Returns: A symbol that indicates the feature type, such
    # as <tt>:FIRE_STATION</tt> or <tt>:LIBRARY</tt>.
    # 
    def self.type
      raise "abstract method \"self.type\" must be overridden"
    end
    
    
    #
    # The map marker graphic for this feature.
    #
    # <b>This is an abstract method that must be overridden in the derived class.</b>
    #
    # Returns: The graphic that should be used to identify
    # this feature on a map (FindIt::MapMarker).
    #
    def self.marker
      raise "abstract method \"self.marker\" must be overridden"
    end
    
    
    #
    # The map marker for this feature.
    #
    # Returns: The value from the class marker method.
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
    # <b>This is an abstract method that must be overridden in the derived class.</b>
    #
    # Returns: The graphic that should be used as a shadow graphic
    # under the map marker for this feature (FindIt::MapMarker).
    #
    def self.marker_shadow
      raise "abstract method \"self.marker_shadow\" must be overridden"
    end
    
    #
    # The map marker shadow for this feature.
    #
    # Returns: The value from the class marker_shadow method.
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