module FindIt
  # Abstract class for the FindIt application.
  #
  # The derived class should be an implementation for a given
  # locality. For instance, the concrete implementation for
  # Austin, TX is class FindIt::Austin_CI_TX_US::App and is
  # defined in file "findit/local/austin.ci.tx.us/app.rb".
  #
  class BaseApp
    
    # Search for features near a given location.
    #
    # <b>This is an abstract method that must be overridden in the derived class.</b>
    #
    # Parameters:
    #
    # * lat -- the latitude (degrees) of the location, as a Float.
    #
    # * lng -- the longitude (degrees) of the location, as a Float.
    #
    # Returns: A list of FindIt::BaseFeature instances.
    #
    def self.nearby(lat, lng)
      raise "abstract method \"self.nearby\" must be overridden"
    end
    
  end # class BaseApp
end # module FindIt
