
class String
  
  def capitalize_words
    self.split.map{|w| w.capitalize}.join(" ")
    end
    
  require 'cgi'
  def html_safe
    CGI::escape_html(self)
  end
  
end


class NilClass
  # So I can use foo.empty? safely on things expected to hold a String.  
  def empty?
    true
  end
end


module FindIt
   
  # Abstract class for a map feature.
  #
  # To implement a new feature, create a derived
  # class that overrides the following methods:
  #
  # * self.type
  # * self.marker
  # * self.marker_shadow
  # * self. closest
  #
  class BaseFeature

    attr_accessor :location
    attr_accessor :title
    attr_accessor :name
    attr_accessor :address
    attr_accessor :city
    attr_accessor :state
    attr_accessor :zip
    attr_accessor :link
    attr_accessor :note
    attr_accessor :distance
    
    # Construct a feature instance.
    #
    # @param location -- Instance of FindIt::Location with the location of this feature.
    #
    # @param params -- Parameters to initialize feature attributes.
    #
    # Supported <i>params</i> are:
    #
    # :title :: a title, such as "Closest fire station" (required)
    # :name :: location name, such as "Groucho Marx Middle School"
    # :address :: street address of the feature (required)
    # :city :: city (required)
    # :state :: state (required)
    # :zip :: postal code
    # :link :: URL to associate with the feature
    # :note :: additional information on the feature
    # :distance :: distance (in miles) from the origin point to the feature (required, see note)
    # :origin :: origin point, as a FindIt::Location instance, used to calculate the distance
    #
    # The <i>distance</i> attribute must be initialized on construction.
    # This can be done with either the <tt>:distance</tt> or the <tt>:origin</tt> parameters.
    # The <tt>:origin</tt> is used only to calculate distance; the coordinate itself is not saved.
    #
    def initialize(location, params = {})
      [:title, :address, :city, :state].each do |p|
        raise "required parameter \":#{p}\" not specified" unless params.has_key?(p)
      end
      raise "must specify either \":distance\" or \":origin\" parameter" unless params.has_key?(:distance) || params.has_key?(:origin)
      @location = location
      @title = params[:title]
      @name = params[:name] if params.has_key?(:name)
      @address = params[:address]
      @city = params[:city]
      @state = params[:state]
      @zip = params[:zip] if params.has_key?(:zip)
      @link = params[:link] if params.has_key?(:link)
      @note = params[:note] if params.has_key?(:note)
      @distance = params[:distance] if params.has_key?(:distance)
      @distance = location.distance(params[:origin]) if params.has_key?(:origin)
    end

    
    # Abstract method: Locate the feature closest to the origin.
    #
    # This method must be overriden in the derived class.
    #
    # @param origin -- origin point, as a FindIt::Location instance
    #
    # @return An instance of this class that contains the closest feature,
    #   or nil if none could be found.
    #
    def self.closest(origin)
      raise "abstract method \"self.closest\" must be overriden"
    end    
    
    def self.type
      raise "abstract method \"self.type\" must be overriden"
    end
    
    def self.marker
      raise "abstract method \"self.marker\" must be overriden"
    end
    
    def marker
      self.class.marker
    end
    
    def self.marker_shadow
      raise "abstract method \"self.marker_shadow\" must be overriden"
    end
    
    def marker_shadow
      self.class.marker_shadow
    end
        
    
    def hint
      s = @title + ": " + (@name.empty? ? @address : @name)
      s.html_safe
    end
    
    
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
      
      result.join("<br />\n")
    end
    
    
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