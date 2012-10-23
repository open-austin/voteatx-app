
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

  /**
   * The id of the DOM element where the map will be placed.
   */
  r.dom_map_elem = document.getElementById(map_id);
  if (! r.dom_map_elem) throw "cannot locate element id \"" + opts.map_id + "\" in page";

  /**
   * Callback for FindIt events.  See send_event() for information.
   */
  r.event_handler = opts.event_handler;

  /**
   * REST endpoint for the Find It Nearby web service.
   */
  r.svc_endpoint = opts.svc_endpoint || (document.URL.replace(/\/[^\/]*$/, "") + "/svc/nearby");

  /**
   * The google.maps.Map we are building.
   */
  r.map = null;
  
  /**
   * XXX document me
   */
  r.oms = null;

  /**
   * The google.maps.Marker on the map that shows where I am.
   */
  r.marker_me = null;
  
  /**
   * List of google.maps.Marker instances for all the features placed on the map.
   */
  r.feature_markers = [];

  /**
   * The info window that currently is active.
   * 
   * TODO - document me
   */
  r.last_opened_info_window = null;

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
   *  * START - A FindIt query has been initiated. No args.
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
   *    given location. Args: {"address" : (address via geoloocation lookup)"}
   *
   *  * ADDRESS_BAD - Was not able to acquire a valid latitude/longitude for
   *    the given location. Args: {"error" : (error message)}
   *    
   *  * NO_FEATURES - No features were found, presumably because the current
   *    location is outside the service area. No args.
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
    
    this.send_event("START");
    
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

    var that = this;

    if (this.map) {
    	
      this.map.panTo(loc);
      
    } else {    	
    	
      this.map = new google.maps.Map(this.dom_map_elem, {
        zoom: 13,
        center: loc,
        mapTypeId: google.maps.MapTypeId.ROADMAP
      });
      
      this.oms = new OverlappingMarkerSpiderfier(this.map, {
        markersWontMove: true,
    	markersWontHide: true,
    	keepSpiderfied: true,
    	nearbyDistance: 10
      });
    		  
      this.oms.addListener('click', function(marker) {
        that.activateInfoWindow(marker);
      });
      this.oms.addListener('spiderfy', function(markers) {
    	  that.closeActiveInfoWindow();    	  
      });
            
      var mapClickCallBack = function(event) {
        that.changeLocation(event.latLng);
      };
      
      google.maps.event.addListener(this.map, 'click', mapClickCallBack);
      
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
   * @return A google.maps.Marker instance.
   */
  placeMe : function(loc) {

    var that = this;

    var icon = new google.maps.MarkerImage("http://maps.google.com/mapfiles/ms/micons/red-dot.png",
        new google.maps.Size(32, 32),  // size
        new google.maps.Point(0,0),       // origin
        new google.maps.Point(16, 32)     // anchor
    );
    
    var shadow = new google.maps.MarkerImage("http://maps.google.com/mapfiles/ms/micons/msmarker.shadow.png",
        new google.maps.Size(59, 32),  // size
        new google.maps.Point(0,0),       // origin
        new google.maps.Point(16, 32)     // anchor
    );

    var marker = new google.maps.Marker({
        map: this.map,
        position: loc,        
        icon: icon,
        shadow: shadow,
        draggable: true,
        title: "You are here",
    });    
    marker.info_window = this.makeInfoWindow("<b>You are here</b>");
    this.oms.addMarker(marker);

    var dragCallBack = function(event) {
      that.changeLocation(event.latLng);
    };

    google.maps.event.addListener(marker, 'dragend', dragCallBack);

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
    this.send_event("START");
    this.marker_me.setPosition(loc);
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
	this.closeActiveInfoWindow();
    this.removeFeatureMarkers();

    var data = "latitude=" + loc.lat() + "&longitude=" + loc.lng();

    var req = new XMLHttpRequest();
    req.open("POST", this.svc_endpoint, false);
    req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.send(data);

    var nearby_features = eval('(' + req.responseText + ')');
    
    if (nearby_features.length == 0) {
      this.send_event("NO_FEATURES");  
      return;
    }

    for (type in nearby_features) {
      this.placeFeatureOnMap(nearby_features[type]);
    }

    this.send_event("COMPLETE");
  },


  /**
   * Callback handler to bind to "click" event on an information window.
   *
   * @param w -- The google.maps.InfoWindow to activate.
   * @param m -- The google.maps.Marker that was clicked on.
   *
   * Any currently active info window will be closed.
   */
  activateInfoWindow : function(marker) {
    this.closeActiveInfoWindow();
	var iw = marker.info_window;
	iw.open(this.map, marker);
	this.last_opened_info_window = iw;
  },
  
  /**
   * TODO - document me
   */
  closeActiveInfoWindow : function() {
    if (this.last_opened_info_window != null) {
	  this.last_opened_info_window.close();
	}
    this.last_opened_info_window = null;
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
   * @return A google.maps.InfoWindow
   *
   * The window will be created but not displayed.
   */
  makeInfoWindow : function(content) {
    return new google.maps.InfoWindow({content: content});
  },
  
  /**
   * Create a MarkerImage instance for a map marker.
   * 
   * @param icon -- Information on the map marker.
   * 
   * @return A google.maps.MarkerImage
   *
   * The icon parameter is a structure with elements: url, width, height.
   */
  makeMarkerIcon : function(marker) {
    return new google.maps.MarkerImage(marker.url,
      new google.maps.Size(marker.width, marker.height),    // size
      new google.maps.Point(0,0),                       // origin
      new google.maps.Point(marker.width/2, marker.height)  // anchor
    );
  },

  /**
   * Create a MarkerImage instance for a map marker shadow.
   * 
   * @param shadow -- Information on the marker shadow.
   * @param icon -- Information on the map marker.
   * 
   * @return A google.maps.MarkerImage, or null if shadow is null.
   * 
   * The shadow and icon parameters are structures with elements: url, width, height.
   */
  makeMarkerShadow : function(shadow, marker) {
    if (shadow) {
      return new google.maps.MarkerImage(shadow.url,
          new google.maps.Size(shadow.width, shadow.height),// size
          new google.maps.Point(0,0),                       // origin
          new google.maps.Point(marker.width/2, marker.height)  // anchor
      );      
    } else {
      return null;
    }
  },

  /**
   * Place a marker on the map for a given feature.
   *
   * @param feature - Information on this feature, as provided by the "Find It Nearby" web service.
   *
   * @return A google.maps.Marker
   */
  placeFeatureOnMap : function(feature) {    
    
    marker = new google.maps.Marker({
      map: this.map,
      position: new google.maps.LatLng(feature.latitude, feature.longitude),
      icon: this.makeMarkerIcon(feature.marker),
      shadow: this.makeMarkerShadow(feature.shadow, feature.marker),
      title: feature.hint,
    });    
    marker.info_window = this.makeInfoWindow(feature.info);
    
    this.oms.addMarker(marker);

    this.feature_markers.push(marker);
    return marker;
  },


};


function isEmpty(str) {
  return (!str || 0 === str.length);
}

function escapeHTML(str) {
  if (isEmpty(str)) {
    return "";
  } else {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
}

String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

String.prototype.capitalizeWords = function() {
  return this.split(/\s+/).map(function(w) {return w.capitalize();}).join(' ');
}

String.prototype.escapeHTML = function() {
  return escapeHTML(this);
}

