/**
 * Class FindIt: find and map features around town.
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
  r.svc_endpoint = opts.svc_endpoint || (document.URL.replace(/\/[^\/]*$/, "") + "/svc/search");

  /**
   * The google.maps.Map we are building.
   */
  r.map = null;
  
  /**
   * An OverlappingMarkerSpiderfier instance, to handle "spiderifying" of markers that
   * are too close together.
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
   * The google.maps.Marker that was most recently activated (clicked on).
   */
  r.last_opened_marker = null;

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
  start : function() {
    
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
    console.log("displayMapAtLocation entered: loc=", loc, "address=", address);

    if (this.map) {
    	
      this.map.panTo(loc);
      
    } else {    	
    	
      this.map = new google.maps.Map(this.dom_map_elem, {
        zoom: 13,
        center: loc,
        mapTypeId: google.maps.MapTypeId.ROADMAP,
      });
      
      this.oms = new OverlappingMarkerSpiderfier(this.map, {
        markersWontMove: true,
        markersWontHide: true,
    	  keepSpiderfied: true,
    	  nearbyDistance: 10
      });
    		  
      this.oms.addListener('click', function(marker) {
        that.activateMarker(marker);
      });
      
      this.oms.addListener('spiderfy', function(markers) {
        that.closeActiveMarker();
      });
      
      google.maps.event.addListener(this.map, 'click', function(event) {
        that.changeLocation(event.latLng);
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
   * @return A google.maps.Marker instance.
   */
  placeMe : function(loc) {

    var that = this;
    
    var marker = this.makeMarker({
      position: loc,
      marker: {
        url: "http://maps.google.com/mapfiles/ms/micons/red-dot.png",
        height: 32,
        width: 32,      
      },
      shadow: {
        url: "http://maps.google.com/mapfiles/ms/micons/msmarker.shadow.png",
        height: 32,
        width: 59,        
      },
      draggable: true,
      title: "You are here.",
      info: "<b>You are here.</b>" +
      	"<p>To change location: drag the marker,<br />click on the map, or type address<br />in the field at bottom of screen.</p>",
    });

    google.maps.event.addListener(marker, 'dragend', function(event) {
      that.changeLocation(event.latLng);
    });

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
    this.removeFeatureMarkers();

    var data = "latitude=" + loc.lat() + "&longitude=" + loc.lng();

    var req = new XMLHttpRequest();
    req.open("POST", this.svc_endpoint, false);
    req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.send(data);

    var nearby_features = eval('(' + req.responseText + ')');
    console.log("searchNearby: response=", nearby_features);
    
    if (nearby_features.length == 0) {
      this.send_event("NO_FEATURES");  
      return;
    }

    for (var i = 0 ; i < nearby_features.length ; ++i) {
      var o = nearby_features[i];
      console.log("searchNearby: creating marker n=", i, "feature=", o);
      this.feature_markers.push(this.makeMarker(o));
    }

    this.send_event("COMPLETE");
  },
  
  
  /**
   * Create a google.maps.Marker for use with the FindIt application.
   * 
   * @param params -- See description of parameters below.
   * 
   * @return A google.maps.Marker instance.
   * 
   * Parameters:
   * * position -- A google.maps.LatLng instance.
   * * latitude, longitude -- Must be specified if "position" not defined.
   * * marker -- Arguments to makeMarkerIcon().
   * * shadow -- Arguments to makeMarkerShadow().
   * * title -- Text message to display when hover over the marker.
   * * draggable -- If true, marker will be draggable.
   * * info -- If specified, text message to be placed in an infoWindow.
   * * region -- If specified, parameters to makePolygon().
   * 
   * In addition to the marker, associated overlays (infoWindow, Polygon) will
   * be created and associated with the marker. See addOverlayMethods() for
   * additional information.
   * 
   * The marker will be registered with the "spiderify" handler.
   */
  makeMarker : function(params) {    

    console.log("makeMarker: entered, params=", params);

    var marker = new google.maps.Marker({
      map: this.map,
      position: params.position || new google.maps.LatLng(params.latitude, params.longitude),
      icon: this.makeMarkerIcon(params.marker),
      shadow: this.makeMarkerShadow(params.shadow, params.marker),
      title: params.title,
      draggable: params.draggable || false,
    });
    
    this.addOverlayMethods(marker);
    
    if (params.info != null) {
      console.log("makeMarker: adding info window overlay to marker");
      marker.add_overlay(this.makeInfoWindow(params.info));
    }
    
    if (params.region != null) {
      console.log("makeMarker: adding polygon overlay to marker");
      marker.add_overlay(this.makePolygon(params.region));
    }
    
    this.oms.addMarker(marker);

    return marker;
  },

  
  /**
   * Modify a google.maps.Marker instance to add support for associated overlays.
   * 
   * Once modified, the following types of overlays can be attached to a marker:
   * 
   * * google.maps.InfoWindow
   * * google.maps.Polygon
   * 
   * The following methods are added to the marker instance:
   * 
   * * add_overlay(overlay) - Attach the overlay to this marker.
   * * open_overlays - Display all the overlays associated with this marker.
   * * close_overlays - Hide all overlays associated with this marker.
   */
  addOverlayMethods : function(marker) {
    
    /** list of overlays associated with this marker */
    marker.overlays = [];
    
    /** attach an overlay to this marker */
    marker.add_overlay = function(overlay) {
      this.overlays.push(overlay);
    }
    
    /** display all the overlays associated with this marker */
    marker.open_overlays = function() {
      var that = this;
        for (var i = 0 ; i < this.overlays.length ; ++i) {
        var ovr = this.overlays[i];
        if (ovr instanceof google.maps.InfoWindow) {
          ovr.open(that.getMap(), that);
        } else if (ovr instanceof google.maps.Polygon) {
          ovr.setVisible(true);       
        } else {
          throw "unsupported or bad overlay type"; 
        }
      }
    }
    
    /** hide all the overlays associated with this marker */
    marker.close_overlays = function() {
      var that = this;
        for (var i = 0 ; i < this.overlays.length ; ++i) {
        var ovr = this.overlays[i];
        if (ovr instanceof google.maps.InfoWindow) {
          ovr.close();
        } else if (ovr instanceof google.maps.Polygon) {
          ovr.setVisible(false);        
        } else {
          throw "unsupported or bad overlay type"; 
        }
      }
    }
    
    return marker;
  },
  

  /**
   * Close all overlays (info window, polygon, etc.) associated with last marker activated.
   * 
   * This method assumes the marker implements features created by addOverlayMethods().
   */
  closeActiveMarker : function() {
    if (this.last_opened_marker != null) {
	    this.last_opened_marker.close_overlays();
	    this.last_opened_marker = null;
	  }
  },
  
  
  /**
   * Open all overlays (info window, polygon, etc.) associated with the given marker.
   * 
   * This method assumes the marker implements features created by addOverlayMethods().
   */
  activateMarker : function(marker) {
    this.closeActiveMarker();
    this.last_opened_marker = marker;    
    marker.open_overlays();
  },


  /**
   * Remove all of the current markers from the map.
   * 
   * Also hides any overlays associated with most recently selected marker.
   *
   * This is done in preparation for moving to a new location.
   */
  removeFeatureMarkers : function() {
    this.closeActiveMarker();
    for (var i = 0 ; i < this.feature_markers.length ; ++i) {
      this.feature_markers[i].setMap(null);
    }
    this.feature_markers = [];
  },


  /**
   * Create a google.maps.InfoWindow that can be displayed when a marker is clicked.
   *
   * @param content -- The HTML content to display in the window.
   *
   * @return A google.maps.InfoWindow
   *
   * The window will be created but not displayed.
   */
  makeInfoWindow : function(content) {
    var s = content.split("\n").join("<br />\n");
    return new google.maps.InfoWindow({content: s});
  },
  
  
  /**
   * Create a google.maps.Polygon that can be displayed when a marker is clicked.
   * 
   * @param params -- See description of parameters below.
   * 
   * @return A google.maps.Polygon
   * 
   * Parameters:
   * * coordinates -- An array of [longitude, latitude] pairs.
   * * stroke_color -- Color for border (default: same as fill color)
   * * stroke_opacity -- 0 (transparent) to 1.0 (opaque) value (default: 0.8)
   * * stroke_weight -- Width of border in pixels (default: 3)
   * * fill_color -- Color for shade fill (default: purple)
   * * fill_opacity -- 0 (transparent) to 1.0 (opaque) value (default: 0.3)
   * 
   * The polygon will be created but not displayed.
   */
  makePolygon : function(params) {    
    var path = new Array();
    for (var i = 0 ; i < params.coordinates.length ; ++i) {
      path.push(new google.maps.LatLng(params.coordinates[i][1], params.coordinates[i][0]));
    }
    
    return new google.maps.Polygon({
      map: this.map,
      paths: path,
      strokeColor: params.stroke_color || params.fill_color || "purple",
      strokeOpacity: params.stroke_opacity || 0.8,
      strokeWeight: params.stroke_weight || 3,
      fillColor: params.fill_color || "purple",
      fillOpacity: params.fill_opacity || 0.3,
      visible: false,
    });
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
      new google.maps.Point(0, 0),                          // origin
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
    if (! shadow) {
      return null;
    }
    return new google.maps.MarkerImage(shadow.url,
      new google.maps.Size(shadow.width, shadow.height),    // size
      new google.maps.Point(0,0),                           // origin
      new google.maps.Point(marker.width/2, marker.height)  // anchor
    );      
  },


};


/**
 * Helper to define classes.
 */
function inherit(m) {
  var o = function() {};
  o.prototype = m;
  return new o();
}

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

