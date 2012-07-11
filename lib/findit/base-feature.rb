require 'location'
require 'cgi' # for escape_html()

class String
  
  def capitalize_words
    self.split.map{|w| w.capitalize}.join(" ")
  end
  
  def html_safe
    CGI::escape_html(self)
  end
  
end

module FindIt
  
  module Feature
    class MapMarker
      
      attr_accessor :url
      attr_accessor :height
      attr_accessor :width
      
      def initialize(url, params = {})
        @url = url
        @height = params[:height] || raise("required parameter \":height\" missing")
        @width = params[:width] || raise("required parameter \":width\" missing")
      end
      
      def to_h
        {
          :url => @url,
          :height => @height,
          :width => @width,
        }
      end
      
    end
  end
  
  
  class BaseFeature

    attr_accessor :title
    attr_accessor :name
    attr_accessor :address
    attr_accessor :city
    attr_accessor :state
    attr_accessor :zip
    attr_accessor :link
    attr_accessor :note
    attr_accessor :location
    attr_accessor :distance
    
    def initialize(location, params = {})
      @location = location
      @title = params[:title] if params.has_key?(:title)
      @name = params[:name] if params.has_key?(:name)
      @address = params[:address] if params.has_key?(:address)
      @city = params[:city] if params.has_key?(:city)
      @state = params[:state] if params.has_key?(:state)
      @zip = params[:zip] if params.has_key?(:zip)
      @link = params[:link] if params.has_key?(:link)
      @note = params[:note] if params.has_key?(:note)
      @distance = params[:distance] if params.has_key?(:distance)
      @distance = location.distance(params[:origin]) if params.has_key?(:origin)
    end

    def self.closest(origin)
      raise "Abstract method \"self.closest\" must be overriden."
    end    
    
    def self.type
      raise "Abstract method \"self.type\" must be overriden."
    end
    
    def self.marker
      raise "Abstract method \"self.marker\" must be overriden."
    end
    
    def marker
      self.class.marker
    end
    
    def self.marker_shadow
      raise "Abstract method \"self.marker_shadow\" must be overriden."
    end
    
    def marker_shadow
      self.class.marker_shadow
    end
        
    
    def hint
      raise("attribute \"title\" undefined") unless @title
      a = []
      a << @name if @name
      a << @address if @address
      (@title + ": " + a.join(", ")).html_safe
    end
    
    
    def info
      raise("attribute \"title\" undefined") unless @title
      raise("attribute \"distance\" undefined") unless @distance
      result = []    
      result << "<b>" + @title.capitalize_words.html_safe + "</b>"
      result << @name.html_safe if @name
      result << @address.html_safe if @address
      if @city
        s = @city
        s += ", " + @state if @state
        s += " " + @zip if @zip
        result << s.html_safe
      end
      result << @note.html_safe if @note
      result << "%.1f mi away" % [@distance]
      if @link
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