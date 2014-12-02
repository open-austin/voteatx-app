$(document).ready(function() {

	/*
	 * Decode URL query string into queryParams.
	 *
	 * For instance, query string: ?time=<val>...
	 * can be accessed as queryParams['time'].
	 *
	 * source: http://stackoverflow.com/a/2880929
	 */
	var queryParams;
	(function() {
		var match, pl = /\+/g, // Regex for replacing addition symbol with a space
		search = /([^&=]+)=?([^&]*)/g, decode = function(s) {
			return decodeURIComponent(s.replace(pl, " "));
		}, query = window.location.search.substring(1);
		queryParams = {};
		while ( match = search.exec(query))
		queryParams[decode(match[1])] = decode(match[2]);
	})();

        /*
         * View-model for Knockout.js.
         */
	function mappViewModel() {
		/*
		 *  Configuration
		 * 
		 * Queries: D (DEBUG), SVC (VOTEATX_SVC url), g (Geolocation), clk (click to update), time (test alt times)
		 * 
		 */
		var DEBUG = false;
		if (queryParams["D"]) {
			DEBUG = true;
		}
		var MAP_ID = 'map_canvas';
		var FALLBACK_LAT = 30.2649;
		var FALLBACK_LNG = -97.7470;
		var VOTEATX_SVC = "http://svc.voteatx.us";
		if (queryParams["SVC"]) {
			VOTEATX_SVC = queryParams["SVC"];
		}
		var BOUNDS = new google.maps.LatLngBounds(new google.maps.LatLng(30.2, -97.9), new google.maps.LatLng(30.5, -97.5));
		var BLUE = [{
			featureType : "all",
			stylers : [{
				saturation : 60
			}, {
				lightness : 20
			}, {
				hue : '#0000BB'
			}]
		}];
		// End Configuration

		/*
		 *  View Model Data
		 */
		var self = this;

                self.oms = null;
		self.map = null;

		// Visibility Bindings
		self.spinner = ko.observable(false);
		self.alert = ko.observable(false);
		self.about = ko.observable(false);

                // id will be set from response.params.election_code after query
                self.electionId = ko.observable(false);

                // true to display link to sample ballot
                self.showSampleBallotLink = ko.pureComputed(function() {
                    return self.electionId() !== false && self.preIsValid();
                });

		self.alertText = ko.observable("");

		self.currentLocAddress = ko.observable("");
		self.currentLocMarker = null;
		self.votingPlaceMarkers = [];
                self.currentInfoWindow = null;

                // true once content for the "about" frame is loaded
		self.haveAboutContent = false;

		self.showBoxes = ko.observable(false);

		self.preID = ko.observable("?");
		self.preIsValid = ko.pureComputed(function() {
			return self.preID() > 0;
		});
		self.preCheck = ko.observable(false);
		this.preCheck.subscribe(function(newValue) {
			this.toggleOverlay("precinct", newValue);
		}, this);
		self.preOverlay = [];

		self.coID = ko.observable("?");
		self.coIsValid = ko.pureComputed(function() {
			return self.coID() > 0;
		});
		self.coCheck = ko.observable(false);
		this.coCheck.subscribe(function(newValue) {
			this.toggleOverlay("city_council", newValue);
		}, this);
		self.coOverlay = [];

		self.jurisChange = ko.observable("TRAVIS");
		this.jurisChange.subscribe(function(newValue) {
			switch ($("#jurisdiction").val()) {
                        case "TRAVIS":
                          break;
                        case "WILLIAMSON":
                          alert("This application currently has voting locations only for Travis County residents.  For Williamson County voting places visit: http://tinyurl.com/qe7ayjp");
                          $("#jurisdiction").val("TRAVIS");
                          break;
                        default:
                          alert("This application currently has voting locations only for Travis County residents.");
                          $("#jurisdiction").val("TRAVIS");
                          break;
			}
		}, this);

		var geocoder;

		// End View Model Data

		/*
		 *  Geolocation
		 */
		function geo_success(position) {
			var latLng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
			setCurrentLocation(latLng, null);
		}

		function geo_error(err) {
			console.log("getCurrentPosition() failed: " + err.message);
		}

		var geo_options = {
			enableHighAccuracy : true,
			maximumAge : 30000,
			timeout : 27000
		};

		// End Geolocation

		/*
		*  Google Maps Methods
		*/

		// Initialize function. Muy Importante.
		function initialize() {
			var mapOptions = {
				zoom : 13,
				center : new google.maps.LatLng(FALLBACK_LAT, FALLBACK_LNG),
				styles : BLUE,
				panControl : false,
				zoomControl : true,
				zoomControlOptions : {
					style : google.maps.ZoomControlStyle.SMALL,
					position : google.maps.ControlPosition.LEFT_CENTER
				},
				streetViewControl : false,
				mapTypeControl : false
			};

			self.map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);


                        self.oms = new OverlappingMarkerSpiderfier(self.map, {
                            markersWontMove: true,
                            markersWontHide: true,
                            keepSpiderfied: true,
                            nearbyDistance: 10
                        });

                        // Bind click event on map to location change.
			if (queryParams["clk"] != false) {
				google.maps.event.addListener(self.map, "click", function(event) {
					setCurrentLocation(event.latLng, null);
				});
			}

                        // Bind click event on markers to open info window.
                        self.oms.addListener("click", function(marker, event) {
                                if (self.currentInfoWindow) {
                                        self.currentInfoWindow.close();
                                        self.currentInfoWindow = null;
                                }
                                if (marker.infowindow) {
                                        marker.infowindow.open(self.map, marker);
                                        self.currentInfoWindow = marker.infowindow;
                                }
                        });

			geocoder = new google.maps.Geocoder();
			initControls();

			// Initialize custom controls
			var infoDiv = document.getElementById('responsiveInfo');
			var startDiv = document.getElementById('pac-input');
			var aboutDiv = document.getElementById('aboutIcon');
			var logoDiv = document.getElementById('oa-logo');
			var atxDiv = document.getElementById('vatx-logo');

			aboutDiv.index = 1;
			aboutDiv.style.cursor = 'help';
			self.map.controls[google.maps.ControlPosition.TOP_RIGHT].push(aboutDiv);
			infoDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.TOP_LEFT].push(infoDiv);
			startDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.LEFT_TOP].push(startDiv);
			logoDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.BOTTOM_LEFT].push(logoDiv);
			atxDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.RIGHT_BOTTOM].push(atxDiv);

			// suppresss geolocation if run with ?g=0
			if (queryParams["g"] != false) {
				navigator.geolocation.getCurrentPosition(geo_success, geo_error, geo_options);
			};

		};

		// Listener for initialize
		google.maps.event.addDomListener(window, 'load', initialize);

		google.maps.Map.prototype.clearMarkers = function() {
			for (var i = 0; i < self.votingPlaceMarkers.length; i++) {
				self.votingPlaceMarkers[i].setMap(null);
			}
			self.votingPlaceMarkers = [];
		};

		// End Google Maps Methods

		/*
		 * Display alert message.
                 *
                 * message.content - Plain text content for the message.
                 * message.severity - "ERROR", "WARNING", "INFO".
                 * message.id - An identifier for one-time messages.
		 */

                // To track message ids that have been displayed.
                var displayedMessageId = {};

		function displayAlert(message) {

                        // Display messages with a given identifier only once.
                        if (message.id) {
                                if (displayedMessageId[message.id]) {
                                        return;
                                }
                                displayedMessageId[message.id] = true;
                        }


                        $("#alerts").removeClass("alert-danger").removeClass("alert-info").removeClass("alert-warning");
			switch (message.severity) {
			case "ERROR":
				$("#alerts").addClass("alert-danger");
				break;
			case "WARNING":
				$("#alerts").addClass("alert-warning");
				break;
			case "INFO":
			default:
				$("#alerts").addClass("alert-info");
				break;
			}

			self.alertText(message.content);
			self.alert(true);
		};

		/*
		 *  Server Request and Map Updating
		 */

		function voteatxQueryURL(latLng) {
			var url = VOTEATX_SVC + "/search?latitude=" + latLng.lat() + "&longitude=" + latLng.lng();
			if (queryParams["time"]) {
				url = url + "&time=" + queryParams["time"];
			}
			return url;
		};

		function setCurrentLocation(latLng, address) {
			if (DEBUG)
				console.log("setCurrentLocation()", {
					'latLng' : latLng,
					'address' : address
				});

			self.map.panTo(latLng);
			self.map.clearMarkers();
			self.spinner(true);
			self.showBoxes(true);

			// reset voting precinct info
			self.preCheck(false);
			if (self.preOverlay[self.preID()]) {
				self.preOverlay[self.preID()].setMap(null);
			}
			self.preID('?');

			// reset council district info
			self.coCheck(false);
			if (self.coOverlay[self.coID()]) {
				self.coOverlay[self.coID()].setMap(null);
			}
			self.coID('?');

			// place the marker on the map at this position
			if (self.currentLocMarker == null) {
				self.currentLocMarker = new google.maps.Marker({
					position : latLng,
					map : self.map,
					title : "You can drag the marker or type a new address.",
					draggable : true
				});
                                self.oms.addMarker(self.currentLocMarker);
				google.maps.event.addListener(self.currentLocMarker, 'dragend', function(event) {
					setCurrentLocation(event.latLng, null);
				});
			} else {
				self.currentLocMarker.setPosition(latLng);
			}

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log("jsonpCallback()", {
						'response' : response
					});

				// Display any message resulting from web service lookup.
				if (response.message) {
					displayAlert(response.message);
				}

				// Save off the district information.
				if (response.districts) {
					if (response.districts.precinct) {
						self.preID(response.districts.precinct.id);
						$(".region-id").prop("disabled", false);
						// TODO - save region, if present
					}
					if (response.districts.city_council) {
						self.coID(response.districts.city_council.id);
						// TODO - save region, if present
					}
				}

                                if (response.params.election_code) {
                                  self.electionId(response.params.election_code);
                                }

				var regexNewline = new RegExp("\\n", "g");

				// Place the voting place markers.
				$.each(response.places, function(index, place) {
					var mLatLng = new google.maps.LatLng(place.location.latitude, place.location.longitude);
					var iconPath = "g/icon_vote";
					switch(place.type) {
					case "EARLY_FIXED":
						iconPath += "_early";
						break;
					case "EARLY_MOBILE":
						iconPath += "_mobile";
						break;
					}

					if (!place.is_open)
						iconPath += "_closed";

					iconPath += ".png";

					var marker = new google.maps.Marker({
						position : mLatLng,
						map : self.map,
						icon : {
                                                        url : iconPath,
                                                        size: new google.maps.Size(72, 72),
                                                        scaledSize: new google.maps.Size(60, 60),
                                                        anchor: new google.maps.Point(30, 30),
                                                },
						title : place.title,
						draggable : false,
					});
                                        self.oms.addMarker(marker);

					var contentString = '<div id="content" style="max-height:300px; overflow: auto;"><div id="bodyContent"><p>' + place.info.replace(regexNewline, "<br/>") + '</p></div></div>';

					marker.infowindow = new google.maps.InfoWindow({
						maxWidth : 250,
						content : contentString
					});

					var loc = response.places[index].location;

					// Now populate the arrays
					self.votingPlaceMarkers.push(marker);
				});

				// Voting place lookup complete.
				self.spinner(false);
			}

			var url = voteatxQueryURL(latLng);

			// Use JSONP to avoid CORS
			$.ajax({
				url : url,
				dataType : 'jsonp',
				error : function(xhr, status, error) {
					alert(error.message);
				},
				success : jsonpCallback
			});

			// update address text field
			if (!address || address == "") {

				// clear current address display while geocoding runs
				self.currentLocAddress(null);

				geocoder.geocode({
					'location' : latLng
				}, function(results, status) {
					if (status === google.maps.GeocoderStatus.OK) {
						self.currentLocAddress(results[0].formatted_address);
					}
				});

			} else {
				self.currentLocAddress(address);
			}

                        // now that we have an address,
                        // remove prompt style from address input field
			$("#pac-input").removeClass("prompt");

			return false;
		};

		/*
		 * Region overlay
		 */

		function displayRegionOverlay(type) {

			if (type === "precinct")
				id = self.preID();
			else
				id = self.coID();

			if (!id || id === "?") {
				console.log("Current location not within a region type = " + type);
				return false;
			}

			var url = VOTEATX_SVC + "/districts/" + type + "/" + id;

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log("jsonpCallback()", {
						'response' : response
					});
				var array = response.region.coordinates[0];
				var polyCoords = [];
				var LatLng;
				$.each(array, function(index, val) {
					if (type === "precinct") {
						LatLng = new google.maps.LatLng(val[1], val[0]);
						polyCoords.push(LatLng);
					} else {
						var arrayNested = array[0];
						$.each(arrayNested, function(i, pos) {
							LatLng = new google.maps.LatLng(pos[1], pos[0]);
							polyCoords.push(LatLng);
						});
					}
				});
				if (DEBUG)
					console.log(polyCoords);

				if (type === "precinct") {
					if (!self.preOverlay[id]) {
						self.preOverlay[id] = new google.maps.Polygon({
							paths : polyCoords,
							strokeColor : '#FF0000',
							strokeOpacity : 0.8,
							strokeWeight : 2,
							fillColor : '#FF0000',
							fillOpacity : 0.15
						});
					}
					self.preOverlay[id].setMap(self.map);
				} else {
					self.coOverlay[id] = new google.maps.Polygon({
						paths : polyCoords,
						strokeColor : '#333',
						strokeOpacity : 0.8,
						strokeWeight : 2,
						fillColor : '#FFFFFF',
						fillOpacity : 0.5
					});
					self.coOverlay[id].setMap(self.map);
				}

				self.spinner(false);

			};

			if (type === "precinct" && self.preOverlay[id]) {
				self.preOverlay[id].setMap(self.map);
				if (DEBUG)
					console.log("from cache");
				return false;
			};
			if (type === "city_council" && self.coOverlay[id]) {
				self.coOverlay[id].setMap(self.map);
				if (DEBUG)
					console.log("from cache");
				return false;
			};

			self.spinner(true);
			$.ajax({
				url : url,
				dataType : 'jsonp',
				error : function(xhr, status, error) {
					alert(error.message);
				},
				success : jsonpCallback
			});
			return false;
		};

		function removeRegionOverlay(type) {
			if (type === "precinct" && self.preOverlay[self.preID()]) {
				if (self.preOverlay) {
					self.preOverlay[self.preID()].setMap(null);
				}
			} else {
				if (self.coOverlay && self.coOverlay[self.coID()]) {
					self.coOverlay[self.coID()].setMap(null);
				}
			}
			return false;
		};

		mappViewModel.prototype.toggleOverlay = function(type, bool) {
			var region;
			if (bool) {
				displayRegionOverlay(type);
			} else {
				removeRegionOverlay(type);
			}
		};


                /*
                 * Sample ballot support
                 */

                // URL of sample ballot posted by Travis County for current precinct.
		self.sampleBallotURL = ko.pureComputed(function() {
                    return "http://www.traviscountyclerk.org/eclerk/content/images/ballots/" + self.electionId() + "/" + self.preID() + "A.pdf";
                });

                // Give warning to avoid download of wrong ballot.
                self.sampleBallotConfirm = function(self) {
                        return confirm("You are about to download the sample ballot for precinct " + self.preID() + ". This ballot will be accurate ONLY if precinct " + self.preID() + " is your home precinct."
                        + "\n\nTo be sure, verify that the location marker is at your home address, and this precinct number matches your voter registration card."
                        + "\n\nClick OK to proceed with the download, or CANCEL to cancel the download.");
                }


		/*
		 *  App Controls
		 */
		mappViewModel.prototype.dismissAlert = function() {
			self.alert(false);
		};

		mappViewModel.prototype.showAbout = function() {
                        if (! self.haveAboutContent) {
                                $.get("about.html", function(data) {
                                        var doc = $.parseHTML(data);
                                        /*
                                         * Need to wrap "doc" with an outer element, because
                                         * .find() searches descendents.
                                         */
                                        var aboutContent = $("<html></html>").append(doc).find("#about-content");
                                        $("#about-content").html(aboutContent);
                                        self.haveAboutContent = true;
                                });
                        }
			self.about(true);
		};

		mappViewModel.prototype.dismissAbout = function() {
			self.about(false);
		};

		function initControls() {
			// AutoComplete for Starting Location (You Are Here)
			var input = document.getElementById('pac-input');
			setupAutocomplete(input);
		};

		function setupAutocomplete(input) {
			// Bounds for AutoComplete

			var opts = {
				bounds : BOUNDS,
				rankBy : google.maps.places.RankBy.DISTANCE,
				componentRestrictions : {
					country : 'us'
				}
			};

			var autocomplete = new google.maps.places.Autocomplete(input, opts);
			//
			// Listener to respond to AutoComplete
			google.maps.event.addListener(autocomplete, 'place_changed', function() {
				$(input).removeClass("prompt");
				var place = autocomplete.getPlace();
				setCurrentLocation(place.geometry.location, place.formatted_address);
			});

		};
	};

        var mappvm = new mappViewModel();
	ko.applyBindings(mappvm);
	
	
	
	// moved from the index
	(function() {
		if (window.addEventListener) {
			window.addEventListener("load", hide_loading_screen, false);
		} else {
			window.attachEvent("onload", hide_loading_screen);
		}
	})();
	function display_loading_screen() {
		document.getElementById("loading_screen").style.display = 'block';
	}
	function hide_loading_screen() {
		document.getElementById("loading_screen").style.display = 'none';
	}
				
	$('#controls').bind("keyup keypress", function(e) {
		var code = e.keyCode || e.which;
		if (code == 13) {
			e.preventDefault();
			return false;
		}
	});
});
