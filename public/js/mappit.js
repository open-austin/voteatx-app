$(document).ready(function() {

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
		var DEBUG = false;
		var MAP_ID = 'map_canvas';
		var FALLBACK_LAT = 30.2649;
		var FALLBACK_LNG = -97.7470;
		var SVC = "http://svc.voteatx.us/";
		var SVC1 = "search?latitude=";
		var SVC2 = "&longitude=";
		var BOUNDS = new google.maps.LatLngBounds(new google.maps.LatLng(30.2, -97.9), new google.maps.LatLng(30.5, -97.5));

		var blue = [{
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

		self.homeLoc = ko.observable("");
		self.homeMarker = null;
		self.homeMarkers = [];
		self.geoMarker = null;
		self.geoMarkers = [];

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
				styles : blue,
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
			directionsDisplay = new google.maps.DirectionsRenderer();
			directionsDisplay.setMap(self.map);
			directionsDisplay.setPanel(document.getElementById('directions-panel'));

			geocoder = new google.maps.Geocoder();
			initControls();

			// Initialize custom controls
			var controlDiv = document.getElementById('responsiveInfo');
			var startDiv = document.getElementById('pac-input');
			var aboutDiv = document.getElementById('aboutIcon');
			var logoDiv = document.getElementById('logo');

			aboutDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.TOP_RIGHT].push(aboutDiv);
			controlDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.TOP_LEFT].push(controlDiv);
			startDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.LEFT_TOP].push(startDiv);
			logoDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.BOTTOM_LEFT].push(logoDiv);
		};
		// Listener for initialize
		google.maps.event.addDomListener(window, 'load', initialize);

		mappViewModel.prototype.toggleOverlay = function(type, bool) {
			var region;
			if (self.homeLoc() == "") {
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

		google.maps.Map.prototype.clearOverlays = function(type) {
			switch(type) {
			case "HOME":
				for (var i = 0; i < self.homeMarkers.length; i++) {
					self.homeMarkers[i].setMap(null);
				}
				self.homeMarkers = [];
				break;
			default:
				for (var i = 0; i < self.geoMarkers.length; i++) {
					self.geoMarkers[i].setMap(null);
				}
				self.geoMarkers = [];
			}
		};
		// End Google Maps Methods

		/*
		*  Server Request and Map Updating
		*/
		// Overloaded - phoneHome(latlng literal) or phoneHome(double lat, double lng)
		function phoneHome(latlng, type) {
			self.map.clearOverlays(type);
			self.spinner(true);

			if (type === "HOME") {
				self.preID('?');
				self.cdID('?');
				self.preCheck(false);
				self.coCheck(false);
			}

			var lat = latlng.lat();
			var lng = latlng.lng();

			var url = SVC + SVC1 + lat + SVC2 + lng;

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
					self.alertText("Address is outside of Travis County!");
					console.log("out of bounds");
					self.alert(true);
					self.spinner(false);
					return;
				};

				self.alert(true);

				// Only get voter info for Home Address!
				if (type === "HOME") {
					self.preID(response.districts.precinct.id);
					self.cdID(response.districts.city_council.id);
				}

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
						$.each(self.homeMarkers, function(index, val) {
							self.homeMarkers[index].infowindow.close();
						});
						$.each(self.geoMarkers, function(index, val) {
							self.geoMarkers[index].infowindow.close();
						});
						marker.infowindow.open(self.map, marker);
						self.psName(loc.name);
						self.psAd(loc.address + ", " + loc.city + ", " + loc.state);
						self.psLatlng = new google.maps.LatLng(loc.latitude, loc.longitude);
					});

					// Now populate the arrays
					if (type === "HOME") {
						self.homeMarkers.push(marker);
						self.spinner(false);
					} else
						self.geoMarkers.push(marker);
					self.spinner(false);
				});
			}

			// Use JSONP to avoid CORS
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

		function drawRegion(type, id) {
			var url = SVC + "districts/" + type + "/" + id;

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
			// Listener to respond to AutoComplete
			google.maps.event.addListener(autocomplete, 'place_changed', function() {
				var place = autocomplete.getPlace();
				self.map.panTo(place.geometry.location);
				phoneHome(place.geometry.location, "HOME");
				self.homeLoc(place.formatted_address);
				if (self.homeMarker != null) {
					self.homeMarker.setPosition(place.geometry.location);
				} else {
					var icon = "icons/home3.svg";
					self.homeMarker = new google.maps.Marker({
						position : place.geometry.location,
						map : self.map,
						icon : icon,
						title : "You won 2nd place in a beauty contest!",
						draggable : false,
					});
				}
			});
		};

		/*
		 *  Geolocation
		 */
		function geo_success(position) {
			var latlng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
			self.map.panTo(latlng);
			phoneHome(latlng, "GEO");
			geocoder.geocode({
				'latLng' : latlng
			}, function(results, status) {
				if (status == google.maps.GeocoderStatus.OK) {
					if (results[1]) {
						self.geoLoc = results[1].formatted_address;
						console.log("located");
						var icon = "icons/yay.svg";
						var icon = new google.maps.MarkerImage("icons/yay.svg", null, /* size is determined at runtime */
						null, /* origin is 0,0 */
						new google.maps.Point(18, 45), /* anchor is bottom center of the scaled image */
						new google.maps.Size(36, 60));
						self.geoMarker = new google.maps.Marker({
							position : latlng,
							map : self.map,
							icon : icon,
							animation: google.maps.Animation.DROP,
							title: "You can drag you!",
							draggable : true,
						});
						// Listen for drags
						google.maps.event.addListener(self.geoMarker, "dragend", function(event) {

							var point = self.geoMarker.getPosition();
							self.map.panTo(point);
							phoneHome(point, "GEO");
						});
						// Listen for clicks
						/*google.maps.event.addListener(self.map, "click", function(event) {

							var point = event.latLng;
							self.map.panTo(point);
							phoneHome(point, "GEO");
							self.geoMarker.setPosition(point);
						});*/
					}
				} else {
					alert("Geocoder failed due to: " + status);
				}
			});
		}

		function geo_error() {
			console.log("Sorry, no position available.");
		}

		var geo_options = {
			enableHighAccuracy : true,
			maximumAge : 30000,
			timeout : 27000
		};
		if (GEOLOCATION) {
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
