
var FindIt = {
    
    svc_endpoint : null,
      
    event_handler : null,
    
    map_id : null,
      
    app_status : null,
      
    position : null,
    
    map : null,
    
    info_windows : null,

    // Changes the "app_status" value, and invokes the status change callback handler.
    set_app_status : function(new_status) {
      // alert("geolocation status = " + new_status);
      this.app_status = new_status;
      if (this.event_handler !== null) {
        this.event_handler({type : this.app_status, position : this.position});
      }
    },
    
    // Begin the FindIt application.
    //
    // This top half attempts automatic geolocation.
    // If geolocation is successful, then "createFeatureMap" will be invoked to create the map.
    start : function (opts) {
      this.svc_endpoint = opts.svc_endpoint || document.URL;
      this.event_handler = opts.handler;
      this.map_id = opts.map_id;
      
      this.app_status = null;
      this.position = null;
      this.map = null;
      this.info_windows = [];
      
      if (navigator.geolocation) {
        this.set_app_status("GEOLOCATION_RUNNING");
        navigator.geolocation.getCurrentPosition(this.geolocationCallbackSuccess, this.geolocationCallbackFail, {
          enableHighAccuracy : true,
          maximumAge : 300000, // 300 sec = 5 min
          timeout : 10000 // 10 sec
        });
        return true;
      } else {
        this.set_app_status("GEOLOCATION_UNSUPPORTED");
        return false;
      }
    },
    
    geolocationCallbackSuccess : function(pos) {
      FindIt.set_app_status("GEOLOCATION_SUCCEEDED");
      FindIt.createFeatureMap(pos);
    },
    
    geolocationCallbackFail : function () {
      FindIt.set_app_status("GEOLOCATION_FAILED");
    },
    
    
    // Locate features near a given position and display them on a map.
    createFeatureMap : function(pos) {
      
      this.set_app_status("FEATURES_SEARCHING");
      
      this.position = pos;
      
      var data = "latitude=" + pos.coords.latitude + "&longitude=" + pos.coords.longitude;
      
      var req = new XMLHttpRequest();
      req.open("POST", this.svc_endpoint, false);
      req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
      req.send(data);  
      
      var nearby = eval('(' + req.responseText + ')');      

      this.set_app_status("FEATURES_MAPPING");
      
      var my_pos = new google.maps.LatLng(pos.coords.latitude, pos.coords.longitude)

      var map_opts = {
        zoom: 13,
        center: my_pos,
        mapTypeId: google.maps.MapTypeId.ROADMAP
      }
      
      this.map = new google.maps.Map(document.getElementById(this.map_id), map_opts);
      
      var marker_me = new google.maps.Marker({
          map: this.map,
          position: my_pos,
          icon: "http://www.google.com/mapfiles/ms/micons/red-dot.png",
          // shadow: "http://www.google.com/mapfiles/ms/micons/msmarker.shadow.png",
          title: "you are here"
      });    

      this.makeInfoWindow(marker_me, "You are here!");
      
      this.placeFeatureOnMap(nearby.library, "library");      
      this.placeFeatureOnMap(nearby.post_office, "post office");
      this.placeFeatureOnMap(nearby.fire_station, "fire station");
      this.placeFeatureOnMap(nearby.moon_tower, "moon tower");

      this.set_app_status("COMPLETE");
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
    

    // Create an information window that opens when a markere is clicked.
    makeInfoWindow : function(marker, content) {
      var infowindow = new google.maps.InfoWindow({content: content});
      google.maps.event.addListener(marker, 'click', function() {
        FindIt.activateInfoWindow(infowindow, marker);
      });      
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
      
      marker = new google.maps.Marker({
        position: new google.maps.LatLng(feature.latitude, feature.longitude),
        map: this.map,
        // for info on marker icons, see:
        // https://sites.google.com/site/gmapsdevelopment/
        icon: "http://www.google.com/mapfiles/ms/micons/blue-dot.png",
        // shadow: "http://www.google.com/mapfiles/ms/micons/msmarker.shadow.png",
        title: title,
      });
      
      infowindow = this.makeInfoWindow(marker, this.infoWindowContentForFeature(feature, descr.capitalizeWords()));
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
