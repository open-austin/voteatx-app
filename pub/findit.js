
function inherit(m) {
  var o = function() {};
  o.prototype = m;  
  return new o();
}


function FindIt(opts) {
  r = inherit(FindIt.methods);

  if (! opts.map_id) throw "required parameter \"map_id\" not defined";
  r.dom_map_elem = document.getElementById(opts.map_id);
  if (! r.dom_map_elem) throw "cannot locate element id \"" + opts.map_id + "\" in page";
  r.event_handler = opts.event_handler;
  r.svc_endpoint = opts.svc_endpoint || document.URL;
  
  r.map = null;
  r.marker_me = null;
  r.feature_markers = [];
  r.info_windows = [];
  r.position = null;
  r.address = null;
  
  r.marker_images = {
    
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
  
  return r;
}


FindIt.methods = {    

    // Invoke the event handler callback.
    send_event : function(event_type, args) {
      // alert("sending event = " + event);
      if (this.event_handler) {
        this.event_handler(event_type, args);
      }
    },
    
    
    // Attempt automatic geolocation, and create map at that position.
    start : function () {
      
      if (! navigator.geolocation) {
        this.send_event("GEOLOCATION_UNSUPPORTED", {});
        return false;
      }
      
      var that = this;
      
      var successCallBack = function(loc) {
        that.send_event("GEOLOCATION_SUCCEEDED", {});
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
      
      this.send_event("GEOLOCATION_RUNNING", {});
      navigator.geolocation.getCurrentPosition(successCallBack, failCallBack, opts);
      
      return true;
    },
    
    
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
    
    
    placeMe : function(loc) {
      
      var that = this;

      var marker = new google.maps.Marker({
          map: this.map,
          position: loc,
          icon: this.marker_images.red_dot,
          shadow: this.marker_images.shadow,
          draggable: true,
          title: "you are here"
      }); 
      
      var dragCallBack = function(event) {
        that.changeLocation(event.latLng);
      };
      
      google.maps.event.addListener(marker, 'dragend', dragCallBack);
      
      this.makeInfoWindow(marker, "<p>You are here!</p><p><i>Drag this marker to explore the city.</i></p>");    
      
      return marker;
    },

    
    // Attempt to geocode a given address, and if successful map that address.
    displayMapAtAddress : function(address) { 
      var that = this;
      var geocodeDoneCallBack = function(results, status) {
        if (status !== google.maps.GeocoderStatus.OK) {
          that.send_event("ADDRESS_BAD", {'message' : "geocoder returned: " + status});
        } else {
          that.displayMapAtLocation(results[0].geometry.location, results[0].formatted_address);
        }
      };      
      var g = new google.maps.Geocoder();
      g.geocode({'address' : address}, geocodeDoneCallBack);      
    },
    

    changeLocation : function(loc) {
      this.findAddress(loc);
      this.searchNearby(loc); 
    },
    
    
    // Find address at a given LatLng position.
    findAddress : function(loc) {
      var that = this;
      var revGeocodeDoneCallBack = function(results, status) {
        if (status !== google.maps.GeocoderStatus.OK) {
          that.send_event("ADDRESS_BAD", {'message' : "geocoder returned: " + status});
        }
	      that.send_event("ADDRESS_GOOD", {'address' : results[0].formatted_address});
      };
      var g = new google.maps.Geocoder();            
      g.geocode({'location' : loc}, revGeocodeDoneCallBack);   
    },
    
        
    // Locate features near a given position and display them on a map.
    searchNearby : function(loc) {      
      this.send_event("FEATURES_SEARCHING", {});
      
      this.removeFeatureMarkers();
      
      var data = "latitude=" + loc.lat() + "&longitude=" + loc.lng();
      
      var req = new XMLHttpRequest();
      req.open("POST", this.svc_endpoint, false);
      req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
      req.send(data);  
      
      var nearby = eval('(' + req.responseText + ')');
      
      this.placeFeatureOnMap(nearby.library, "library");      
      this.placeFeatureOnMap(nearby.post_office, "post office");
      this.placeFeatureOnMap(nearby.fire_station, "fire station");
      this.placeFeatureOnMap(nearby.moon_tower, "moon tower");

      this.send_event("COMPLETE", {});
    },
    
    
    // Callback handler to bind to "click" event on an information window.
    activateInfoWindow : function(w, m) {
      for (var i = 0 ; i < this.info_windows.length ; ++i) {
        if (this.info_windows[i] !== w) {
          this.info_windows[i].close();
        }
      }
      w.open(this.map, m);      
    },
    
    removeFeatureMarkers : function() {
      for (var i = 0 ; i < this.feature_markers.length ; ++i) {
        this.feature_markers[i].setMap(null);
      }
      this.feature_markers = [];
    },
    

    // Create an information window that opens when a markere is clicked.
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
    
    
    // Place a marker on the map for a given feature.
    placeFeatureOnMap : function(feature, descr) {
      var title =  "Nearest " + descr + ": ";
      if (! isEmpty(feature.name)) {
        title = title + feature.name + ", "
      }
      title = title + feature.address;
      
      // for info on marker icons, see:
      // https://sites.google.com/site/gmapsdevelopment/
      // http://duncan99.wordpress.com/2011/09/25/google-maps-api-adding-markers/
      

      
      marker = new google.maps.Marker({
        position: new google.maps.LatLng(feature.latitude, feature.longitude),
        map: this.map,
        icon: this.marker_images.blue_dot,
        shadow: this.marker_images.shadow,
        title: title,
      });      
      
      infowindow = this.makeInfoWindow(marker, this.infoWindowContentForFeature(feature, descr.capitalizeWords()));
      
      this.feature_markers.push(marker);
      return marker;
    },

    
    // Build info window content for a feature.
    infoWindowContentForFeature : function(feature, descr) {
      var content = "<p><b>Nearest " + descr + "</b></p>\n<p>";
      if (! isEmpty(feature.name)) {
        content = content + feature.name + "<br />\n";
      }
      content = content + feature.address + "<br />\n" +
        feature.distance.toFixed(1) + " mi away</p>\n" + 
        "<p><i>clickable link goes here</i></p>";
      return content;
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
