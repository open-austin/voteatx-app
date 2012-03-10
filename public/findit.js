
/**
 * Helper to define classes.
 */
function inherit(m) {
  var o = function() {};
  o.prototype = m;  
  return new o();
}


/**
 * Class to find and map features around Austin.
 * 
 * @param map_id - The HTML DOM id of the division in which the map will be placed.
 * @param options
 * 
 * Options:
 * 
 *  * event_handler - Callback that is invoked as events are processed.
 *    See the send_event() method for more information.
 *    
 *  * svc_entpoint - URL of "Find It Nearby" web service endpoint. As
 *    distributed, this is calculated automatically, and should not need
 *    to be set.
 */
function FindIt(map_id, opts) {
  r = inherit(FindIt.methods);

  r.dom_map_elem = document.getElementById(map_id);
  if (! r.dom_map_elem) throw "cannot locate element id \"" + opts.map_id + "\" in page";
  
  r.event_handler = opts.event_handler;
  
  r.svc_endpoint = opts.svc_endpoint || (document.URL.replace(/\/[^\/]*$/, "") + "/svc/nearby");
  
  /**
   * The google.maps.Map we are building.
   */
  r.map = null;
  
  /**
   * The google.maps.Marker on the map that shows where I am.
   */
  r.marker_me = null;
  
  /**
   * List of google.maps.Marker instances for all the features placed on the map.
   */
  r.feature_markers = [];
  
  /**
   * List of google.maps.InfoWindow instances for all the markers (both me and features).
   */
  r.info_windows = [];

  /**
   * Pre-built marker images that are used in the application.
   * 
   * For info on Google Maps marker icons, see:
   * * https://sites.google.com/site/gmapsdevelopment/
   * * http://duncan99.wordpress.com/2011/09/25/google-maps-api-adding-markers/
   */  
  var marker_images = {
    
    'blue_dot' : new google.maps.MarkerImage(
        "http://maps.google.com/mapfiles/ms/micons/blue-dot.png",
        new google.maps.Size(32, 32), // size
        new google.maps.Point(0,0), // origin
        new google.maps.Point(16, 32) // anchor
      ),
    
    'red_dot' : new google.maps.MarkerImage(
        "http://maps.google.com/mapfiles/ms/micons/red-dot.png",
        new google.maps.Size(32, 32), // size
        new google.maps.Point(0,0), // origin
        new google.maps.Point(16, 32) // anchor
      ),
    
    'shadow' : new google.maps.MarkerImage(
        "http://maps.google.com/mapfiles/ms/micons/msmarker.shadow.png",
        new google.maps.Size(59, 32), // size
        new google.maps.Point(0,0), // origin
        new google.maps.Point(16, 32) // anchor
    ),
    
  };

  /**
   * Prebuilt google.maps.MarkerImage instances for placing markers on the map.
   */
  r.marker_images = marker_images;
      
  /**
   * The sorts of features that are returned by the "Find It Nearby" web service.
   */
  r.recognized_features = {
   ME : {title: null, marker: marker_images.red_dot, marker_shadow: marker_images.shadow},
   LIBRARY : {title: "library", marker: marker_images.blue_dot, marker_shadow: marker_images.shadow},
   POST_OFFICE : {title: "post office", marker: marker_images.blue_dot, marker_shadow: marker_images.shadow},
   FIRE_STATION : {title: "fire station", marker: marker_images.blue_dot, marker_shadow: marker_images.shadow},
   MOON_TOWER : {title: "moon tower", marker: marker_images.blue_dot, marker_shadow: marker_images.shadow}
  };                
   
  
  return r;
}


FindIt.methods = {    

    /**
     * Invoke the event handler callback.
     * 
     * @param event_type -- The event type sent to the callback handler.
     * @param args -- Additional arguments sent to the callback handler. (optional)
     * 
     * The prototype of the callback handler is:
     * 
     *   function(event_type, args)
     * 
     *  The "event_type" values used in this class are as follows:
     *  
     *  * GEOLOCATION_RUNNING  - Device is attempting to acquire the current location.
     *    No args.
     *  
     *  * GEOLOCATION_UNSUPPORTED - Device does not support geolocation. No args.
     *  
     *  * GEOLOCATION_FAILED - Device was not able to acquire current location.
     *    Args: {"error" : (error message)}
     *  
     *  * GEOLOCATION_SUCCEEDED - Device has successfully acquired current location.
     *    No args.
     *  
     *  * ADDRESS_GOOD - A valid latitude/longitude has been acquired for the
     *   given location. Args: {"address" : (address via geoloocation lookup)"
     *  
     *  * ADDRESS_BAD - Was not able to acquire a valid latitude/longitude for
     *    the given location. Args: {"error" : (error message)}
     *    
     *  * COMPLETE - Done. Nearby features have been located and placed on
     *    the map. No args.
     */
    send_event : function(event_type, args) {
      // alert("sending event = " + event);
      if (this.event_handler) {
        this.event_handler(event_type, args);
      }
    },
    
    
    /**
     * Attempt automatic geolocation, and create map at that position.
     * 
     * The browser getCurrentPosition() is invoked to determine the current
     * location of the user. That runs asynchronously, so this method
     * returns quickly, and the geolocation callback will be triggered
     * once the process resolves.
     */
    start : function () {
      
      if (! navigator.geolocation) {
        this.send_event("GEOLOCATION_UNSUPPORTED");
        return false;
      }
      
      var that = this;
      
      var successCallBack = function(loc) {
        that.send_event("GEOLOCATION_SUCCEEDED");
        that.displayMapAtLocation(new google.maps.LatLng(loc.coords.latitude, loc.coords.longitude));
      };
      
      var failCallBack = function(error) {
        that.send_event("GEOLOCATION_FAILED", {'error' : error});
      };
      
      var opts = {
        enableHighAccuracy : true,
        maximumAge : 300000, // 300 sec = 5 min
        timeout : 10000 // 10 sec
      };
      
      this.send_event("GEOLOCATION_RUNNING");
      navigator.geolocation.getCurrentPosition(successCallBack, failCallBack, opts);
      
      return true;
    },
    
    
    /**
     * Display a map at the given location, then invoke search for nearby features.
     * 
     * @param loc -- A google.maps.LatLng with current location.
     * @param address -- Verified address at this location if known, otherwise
     *   null and we will figure it out.
     */
    displayMapAtLocation : function(loc, address) {
    	
      if (this.map) {
    	  this.map.panTo(loc);
      } else {    	
        this.map = new google.maps.Map(this.dom_map_elem, {
          zoom: 13,
          center: loc,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        });
      }
      
      if (this.marker_me) {
    	  this.marker_me.setPosition(loc);    	  
      } else {
    	  this.marker_me = this.placeMe(loc);
      }

      if (address) {
        this.send_event("ADDRESS_GOOD", {'address' : address});
      } else {
        this.findAddress(loc);
      }
      
      this.searchNearby(loc);
    },
    
    
    /**
     * Attempt to geocode a given address, and, if successful, map that address.
     * 
     * @param address - The address to locate.
     * 
     * This is used instead of start() if you want to map a specific address.
     * 
     * A call to the Google Maps geocoder is invoked to determine the
     * specified location. That runs asynchronously, so this method
     * returns quickly, and the geolocation callback will be triggered
     * once the process resolves.
     */
    displayMapAtAddress : function(address) { 
      var that = this; 
      var geocodeDoneCallBack = function(results, status) {
        if (status !== google.maps.GeocoderStatus.OK) {
          that.send_event("ADDRESS_BAD", {'error' : "geocoder returned: " + status});
        } else {
          that.displayMapAtLocation(results[0].geometry.location, results[0].formatted_address);
        }
      };      
      var g = new google.maps.Geocoder();
      g.geocode({'address' : address}, geocodeDoneCallBack);      
    },
    

    
    /**
     * Place the "I am here" marker on the map.
     * 
     * @param loc -- A google.maps.LatLng with my current location.
     * 
     * @returns A google.maps.Marker instance.
     */
    placeMe : function(loc) {
      
      var that = this;
      
      var feature_info = this.recognized_features.ME;

      var marker = new google.maps.Marker({
          map: this.map,
          position: loc,
          icon: feature_info.marker,
          shadow: feature_info.marker_shadow,
          draggable: true,
          title: "You are here",
      }); 
      
      var dragCallBack = function(event) {
        that.changeLocation(event.latLng);
      };
      
      google.maps.event.addListener(marker, 'dragend', dragCallBack);
      
      this.makeInfoWindow(marker, "<b>You are here</b><br /><i>Drag this marker to explore the city.</i>");    
      
      return marker;
    },


    /**
     * Move the user's position to a new location.
     * 
     * @param loc -- A google.maps.LatLng with the new location.
     * 
     * This method is invoked when the user drags the "you are here"
     * marker to a different place.
     */
    changeLocation : function(loc) {
      this.findAddress(loc);
      this.searchNearby(loc); 
    },
    
    
    /**
     * Find the street address at a given location.
     * 
     * @param loc -- A google.maps.LatLng of the location to find.
     * 
     * This application doesn't do anything with that address. It
     * just sends an ADDRESS_GOOD (or ADDRESS_BAD) event to the
     * browser, so that it can display the geolocated adddress.
     */
    findAddress : function(loc) {
      var that = this;
      var revGeocodeDoneCallBack = function(results, status) {
        if (status === google.maps.GeocoderStatus.OK) {
          that.send_event("ADDRESS_GOOD", {'address' : results[0].formatted_address});
        } else {
          that.send_event("ADDRESS_BAD", {'error' : "geocoder returned: " + status});
        }
      };
      var g = new google.maps.Geocoder();            
      g.geocode({'location' : loc}, revGeocodeDoneCallBack);   
    },
    
        
    /**
     * Locate features near a given position and display them on a map.
     * 
     * @param loc -- A google.maps.LatLng of the location to search around.
     */
    searchNearby : function(loc) {      
      this.removeFeatureMarkers();
      
      var data = "latitude=" + loc.lat() + "&longitude=" + loc.lng();
      
      var req = new XMLHttpRequest();
      req.open("POST", this.svc_endpoint, false);
      req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
      req.send(data);  
      
      var nearby_features = eval('(' + req.responseText + ')');
      
      for (type in nearby_features) {
        this.placeFeatureOnMap(this.recognized_features[type], nearby_features[type]);
      }      
      
      this.send_event("COMPLETE");
    },
    
    
    /**
     * Callback handler to bind to "click" event on an information window.
     * 
     * @param w -- The google.maps.InfoWindow to activate.
     * @param m -- The google.maps.Marker that was clicked on.
     * 
     * All other info windows will be closed.
     * 
     * The info windows are tracked in the "info_windows[]" lists.
     */
    activateInfoWindow : function(w, m) {
      for (var i = 0 ; i < this.info_windows.length ; ++i) {
        if (this.info_windows[i] !== w) {
          this.info_windows[i].close();
        }
      }
      w.open(this.map, m);      
    },
    
    
    /**
     * Remove all of the current markers from the map.
     * 
     * The markers are tracked in the "feature_markers[]" list.
     * 
     * This is done in preparation for moving to a new location.
     */
    removeFeatureMarkers : function() {
      for (var i = 0 ; i < this.feature_markers.length ; ++i) {
        this.feature_markers[i].setMap(null);
      }
      this.feature_markers = [];
    },
    

    /**
     * Create an information window that opens when a marker is clicked.
     * 
     * @param marker -- The marker to attach the new info window to.
     * @param content -- The HTML content to display in the window.
     * 
     * @returns A google.maps.InfoWindow
     * 
     * The window will be created but not displayed. A callback
     * will be setup to call activateInfoWindow() when the
     * marker is clicked. The new info window will be added
     * to the "info_windows[]" list.
     */
    makeInfoWindow : function(marker, content) {
      var that = this;
      var infowindow = new google.maps.InfoWindow({content: content});
      var m1 = marker;
      var markerClickCallBack = function() {
    		that.activateInfoWindow(infowindow, m1);
    	};
      google.maps.event.addListener(marker, 'click', markerClickCallBack);      
      this.info_windows.push(infowindow);
      return infowindow;
    },
    
    
    /**
     * Place a marker on the map for a given feature.
     * 
     * @param feature_info - An entry from "recognized_features" that describes this feature.
     * @param feature - Information on this feature, as provided by the "Find It Nearby" web service.
     * 
     * @return A google.maps.Marker
     */
    placeFeatureOnMap : function(feature_info, feature) {
      var title =  "Nearest " + feature_info.title + ": ";
      if (! isEmpty(feature.name)) {
        title = title + feature.name + ", "
      }
      title = title + feature.address;
      
      marker = new google.maps.Marker({
        position: new google.maps.LatLng(feature.latitude, feature.longitude),
        map: this.map,
        icon: feature_info.marker,
        shadow: feature_info.marker_shadow,
        title: title,
      });      
      
      infowindow = this.makeInfoWindow(marker, this.infoWindowContentForFeature(feature_info, feature));
      
      this.feature_markers.push(marker);
      return marker;
    },

    
    /**
     *  Build info window content for a feature.
     *  
     * @param feature_info - An entry from "recognized_features" that describes this feature.
     * @param feature - Information on this feature, as provided by the "Find It Nearby" web service.
     * 
     *  @return An HTML text string.
     */
    infoWindowContentForFeature : function(feature_info, feature) {
      var result = ["<b>Nearest " + feature_info.title.capitalizeWords().escapeHTML() + "</b>"];
      if (! isEmpty(feature.name)) {
        result.push(feature.name.escapeHTML());
      }
      result.push(feature.address.escapeHTML());
      if (! isEmpty(feature.info)) {
        result.push(feature.info.escapeHTML());
      }
      result.push(feature.distance.toFixed(1) + " mi away");
      if (! isEmpty(feature.link)) {
        result.push("<a href=\"" + feature.link.escapeHTML() + "\">more info ...</a>");
      }
      return result.join("<br />\n");
    }
  
  };


  function isEmpty(str) {
    return (!str || 0 === str.length);
  }

  String.prototype.capitalize = function() {
    return this.charAt(0).toUpperCase() + this.slice(1);
  }
  
  String.prototype.capitalizeWords = function() {
    return this.split(/\s+/).map(function(w) {return w.capitalize();}).join(' ');
  }
  
  String.prototype.escapeHTML = function() {
	return this.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
