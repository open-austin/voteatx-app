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

	function RegionOverlayAlert() {
		if (!document.getElementById('toggleAlert')) {
			var alertUI = document.createElement('div');
			var parent = document.getElementById('place-holder');
			alertUI.innerHTML = 'You must enter an address before overlays can be displayed';
			alertUI.className = "alert alert-danger";
			$(alertUI).attr('id', 'toggleAlert');
			parent.appendChild(alertUI);
			setTimeout(function() {
				$(alertUI).remove();
			}, 3000);
		}
	}

	function mappViewModel() {
		/*
		 *  Configuration
		 */
		var DEBUG = true; // FIXME
		var MAP_ID = 'map_canvas';
		var FALLBACK_LAT = 30.2649;
		var FALLBACK_LNG = -97.7470;
		var VOTEATX_SVC = "http://svc.voteatx.us";
		var BOUNDS = new google.maps.LatLngBounds(new google.maps.LatLng(30.2, -97.9), new google.maps.LatLng(30.5, -97.5));
		var URL = window.location.toString();
		console.log("url: " + URL);

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

		self.map = null;

		// Visibility Bindings
		self.spinner = ko.observable(false);
		self.alert = ko.observable(false);
		self.about = ko.observable(false);
		self.showBoxes = ko.pureComputed(function() {
			return (self.currentLocAddress() != "");
		}, this);

		self.currentLocAddress = ko.observable("");
		self.currentLocMarker = null;
		self.votingPlaceMarkers = [];

		self.cdID = ko.observable("<i class='fa fa-arrow-down'></i>");
		self.preID = ko.observable('<i class="fa fa-arrow-circle-down"></i>');
		self.psAd = ko.observable("");
		self.psName = ko.observable("nearby polling stations");
		self.psLatlng = null;

		self.preOverlay = null;
		self.preCheck = ko.observable(false);
		this.preCheck.subscribe(function(newValue) {
			this.toggleOverlay("precinct", newValue);
		}, this);
		self.coOverlay = null;
		self.coCheck = ko.observable(false);
		this.coCheck.subscribe(function(newValue) {
			this.toggleOverlay("city_council", newValue);
		}, this);

		self.alertText = ko.observable("Welcome to VoteATX!");

		var geocoder;
		var directionsDisplay;
		var directionsService = new google.maps.DirectionsService();

		// End View Model Data
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

                        google.maps.event.addListener(self.map, "click", function(event) {
                                setCurrentLocation(event.latLng, null);
                        });

                        /* NOT USED (I think)
			directionsDisplay = new google.maps.DirectionsRenderer();
			directionsDisplay.setMap(self.map);
			directionsDisplay.setPanel(document.getElementById('directions-panel'));
                        */

			geocoder = new google.maps.Geocoder();
			initControls();

			// Initialize custom controls
			var controlDiv = document.getElementById('responsiveInfo');
			var startDiv = document.getElementById('pac-input');
			var aboutDiv = document.getElementById('aboutIcon');
			var logoDiv = document.getElementById('oa-logo');
			var atxDiv = document.getElementById('vatx-logo');

			aboutDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.TOP_RIGHT].push(aboutDiv);
			controlDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.TOP_LEFT].push(controlDiv);
			startDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.LEFT_TOP].push(startDiv);
			logoDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.BOTTOM_LEFT].push(logoDiv);
			atxDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.RIGHT_BOTTOM].push(atxDiv);
		};
		// Listener for initialize
		google.maps.event.addDomListener(window, 'load', initialize);

		mappViewModel.prototype.toggleOverlay = function(type, bool) {
			var region;
			if (self.currentLocAddress() == "") {
				self.alertText("You must enter an address before overlays can be displayed!");
				self.alert(true);
				self.preCheck(false);
				self.coCheck(false);
				return;
			}
			if (!bool) {
				if (type === "precinct")
					self.preOverlay.setMap(null);
				else
					self.coOverlay.setMap(null);

				return;
			} else {
				if (type === "precinct")
					region = drawRegion(type, self.preID());
				else
					region = drawRegion(type, self.cdID());
				if (DEBUG)
					console.log(region);
			}
		};

		google.maps.Map.prototype.clearOverlays = function() {
                        for (var i = 0; i < self.votingPlaceMarkers.length; i++) {
                                self.votingPlaceMarkers[i].setMap(null);
                        }
                        self.votingPlaceMarkers = [];
                };

		// End Google Maps Methods

                function voteatxQueryURL(latlng) {
                        var url = VOTEATX_SVC + "/search?latitude=" + latlng.lat() + "&longitude=" + latlng.lng();
			if (queryParams["time"] != "") {
				url = url + "&time=" + queryParams["time"];
			}
                        return url;
                };

		/*
		*  Server Request and Map Updating
		*/

		function setCurrentLocation(latlng, address) {
                        self.map.panTo(latlng);
			self.map.clearOverlays();
			self.spinner(true);

                        self.preID('?');
                        self.cdID('?');
                        self.preCheck(false);
                        self.coCheck(false);

                        if (self.currentLocMarker == null) {
                                self.currentLocMarker = new google.maps.Marker({
                                        position : latlng,
                                        map : self.map,
                                        // XXX - find a nice icon, using default map pin for now
                                        //icon : "icons/home3.svg",
                                        title : "You are here. Click map to change position.",
                                });
                        } else {
                                self.currentLocMarker.setPosition(latlng);
                        }

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log(response);

				self.alertText(response.message.content);
				switch(response.message.severity) {
				case "WARNING":
					$("#alerts").addClass("alert-warning").removeClass("alert-info").removeClass("alert-danger");
					break;
				case "ERROR":
					$("#alerts").addClass("alert-danger").removeClass("alert-info").removeClass("alert-warning");
					break;
				default:
					$("#alerts").addClass("alert-info").removeClass("alert-warning").removeClass("alert-danger");
				}

				// Let user know their address is outside of the bounds.
				// Need response from server indicating the error. This is a hack!
				if (response.places.length == 1) {
					self.alertText("Address is outside of service area");
					console.log("out of bounds");
					self.alert(true);
					self.spinner(false);
					return;
				};

				self.alert(true);

                                self.preID(response.districts.precinct.id);
                                self.cdID(response.districts.city_council.id);

				var regex = new RegExp("\\n", "g");

				$.each(response.places, function(index, val) {
					var mLatLng = new google.maps.LatLng(val.location.latitude, val.location.longitude);
					var iconPath = "mapicons/icon_vote";
					switch(val.type) {
					case "EARLY_VOTING_FIXED":
						iconPath += "_early";
						break;
					case "EARLY_VOTING_MOBILE":
						iconPath += "_mobile";
						break;
					}

					if (!val.is_open)
						iconPath += "_closed";

					iconPath += ".png";

					var icon = new google.maps.MarkerImage(iconPath);
					var marker = new google.maps.Marker({
						position : mLatLng,
						map : self.map,
						icon : icon,
						title : val.title,
						draggable : false,
					});
					var contentString = '<div id="content" style="max-height:300px; overflow: auto;">' + '<div id="bodyContent"><p>' + val.info.replace(regex, "<br/>") + '</p></div></div>';
					marker.infowindow = new google.maps.InfoWindow({
						maxWidth : 250,
						content : contentString
					});

					var loc = response.places[index].location;
					// Bind the Info Window to the Marker
					google.maps.event.addListener(marker, 'click', function() {
						$.each(self.votingPlaceMarkers, function(index, val) {
							self.votingPlaceMarkers[index].infowindow.close();
						});
						marker.infowindow.open(self.map, marker);
						self.psName(loc.name);
						self.psAd(loc.address + ", " + loc.city + ", " + loc.state);
						self.psLatlng = new google.maps.LatLng(loc.latitude, loc.longitude);
					});

					// Now populate the arrays
                                        self.votingPlaceMarkers.push(marker);
                                        self.spinner(false);
				});
			}

                        var url = voteatxQueryURL(latlng);

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

                                geocoder.geocode({'location' : latlng}, function(results, status) {
                                        if (status === google.maps.GeocoderStatus.OK) {
                                                self.currentLocAddress(results[0].formatted_address);
                                        }
                                });

                        } else {
                                self.currentLocAddress(address);
                        }

			return false;
		};

		function drawRegion(type, id) {
			var url = VOTEATX_SVC + "/districts/" + type + "/" + id;

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log(response);
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
					self.preOverlay = new google.maps.Polygon({
						paths : polyCoords,
						strokeColor : '#FF0000',
						strokeOpacity : 0.8,
						strokeWeight : 2,
						fillColor : '#FF0000',
						fillOpacity : 0.15
					});
					self.preOverlay.setMap(self.map);
				} else {
					self.coOverlay = new google.maps.Polygon({
						paths : polyCoords,
						strokeColor : '#333',
						strokeOpacity : 0.8,
						strokeWeight : 2,
						fillColor : '#FFFFFF',
						fillOpacity : 0.5
					});
					self.coOverlay.setMap(self.map);
				}

			};

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

		/*
		 *  App Controls
		 */
		mappViewModel.prototype.dismissAlert = function() {
			self.alert(false);
		};

		mappViewModel.prototype.showAbout = function() {
			self.about(true);
		};

		mappViewModel.prototype.hideAbout = function() {
			self.about(false);
		};

		mappViewModel.prototype.toggleAbout = function() {
			if (self.about() === false)
				self.about(true);
			else
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
				var place = autocomplete.getPlace();
				setCurrentLocation(place.geometry.location, place.formatted_address);
                        });

		};

		/*
		 *  Geolocation
		 */
		function geo_success(position) {
			var latlng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
			setCurrentLocation(latlng, null);
		}


		function geo_error(err) {
			console.log("getCurrentPosition() failed: " + err.message);
		}

		var geo_options = {
			enableHighAccuracy : true,
			maximumAge : 30000,
			timeout : 27000
		};

		// suppresss geolocation if run with ?g=0
		if (queryParams["g"] != false) {
			navigator.geolocation.getCurrentPosition(geo_success, geo_error, geo_options);
		};
		// End Geolocation

		// KOut+BStrap Integration
		ko.bindingHandlers.radio = {
			init : function(element, valueAccessor, allBindings, data, context) {
				var $buttons, $element, observable;
				observable = valueAccessor();
				if (!ko.isWriteableObservable(observable)) {
					throw "You must pass an observable or writeable computed";
				}
				$element = $(element);
				if ($element.hasClass("btn")) {
					$buttons = $element;
				} else {
					$buttons = $(".btn", $element);
				}
				elementBindings = allBindings();
				$buttons.each(function() {
					var $btn, btn, radioValue;
					btn = this;
					$btn = $(btn);
					radioValue = elementBindings.radioValue || $btn.attr("data-value") || $btn.attr("value") || $btn.text();
					$btn.on("click", function() {
						observable(ko.utils.unwrapObservable(radioValue));
					});
					return ko.computed({
						disposeWhenNodeIsRemoved : btn,
						read : function() {
							$btn.toggleClass("active", observable() === ko.utils.unwrapObservable(radioValue));
						}
					});
				});
			}
		};

		ko.bindingHandlers.checkbox = {
			init : function(element, valueAccessor, allBindings, data, context) {
				var $element, observable;
				observable = valueAccessor();
				if (!ko.isWriteableObservable(observable)) {
					throw "You must pass an observable or writeable computed";
				}
				$element = $(element);
				$element.on("click", function() {
					observable(!observable());
				});
				ko.computed({
					disposeWhenNodeIsRemoved : element,
					read : function() {
						$element.toggleClass("active", observable());
					}
				});
			}
		};

		// Here's a custom Knockout binding that makes elements shown/hidden via jQuery's fadeIn()/fadeOut() methods
		// Could be stored in a separate utility library
		ko.bindingHandlers.fadeVisible = {
			init : function(element, valueAccessor) {
				// Initially set the element to be instantly visible/hidden depending on the value
				var value = valueAccessor();
				$(element).toggle(ko.unwrap(value));
				// Use "unwrapObservable" so we can handle values that may or may not be observable
			},
			update : function(element, valueAccessor) {
				// Whenever the value subsequently changes, slowly fade the element in or out
				var value = valueAccessor();
				ko.unwrap(value) ? $(element).fadeIn() : $(element).fadeOut();
			}
		};
	};

	ko.applyBindings(new mappViewModel());
});
