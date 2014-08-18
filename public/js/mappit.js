$(document).ready(function() {

	/*
	 *  TODO: Use this to create a special select with pertinent information about polling stations
	 * 		Open/Closed icon, Name of Stations, ETA (and eventually +wait)
	 *  TODO: To achieve this, bootstrap-select must be forked and templating implemented,
	 * 		preferably KO.js templating
	 */
	function PollingStation(val, open) {
		var self = this;

		self.name = val.name;
		self.address = val.address;
		self.isOpen = open;
	};

	/*
	 * 	Controls to toggle Precint and City Council overlays on the map
	 */
	function RegionOverlayControl(div, map) {
		// Set CSS styles for the DIV containing the control
		// Setting padding to 5 px will offset the control
		// from the edge of the map
		div.style.padding = '10px';

		// Set CSS for the control border
		var controlUI = document.createElement('div');
		$(controlUI).addClass("mapCtrl");
		controlUI.title = '';
		div.appendChild(controlUI);

		// Set CSS for the control interior
		// TODO: Move to CSS file
		var controlText = document.createElement('div');
		controlText.style.fontFamily = 'Arial,sans-serif';
		controlText.style.fontSize = '12px';
		controlText.style.paddingLeft = '4px';
		controlText.style.paddingRight = '4px';
		controlText.innerHTML = '<b>  Regions  </b>';
		controlUI.appendChild(controlText);

		// Append inputs
		var toggleUI = $("#regionOverlayChecks");
		$(div).append(toggleUI);

		// Hide/Show checkboxes on hover
		$(div).hover(function() {
			$(toggleUI).toggle();
		});
	};

	function mappViewModel() {
		/*
		 *  Configuration
		 */
		var DEBUG = true;
		var MAP_ID = 'map_canvas';
		var FALLBACK_LAT = 30.2649;
		var FALLBACK_LNG = -97.7470;
		var SVC = "http://svc.voteatx.us/";
		var SVC1 = "search?latitude=";
		var SVC2 = "&longitude=";

		$("#map-canvas").css("height", $(window).height() - $("#messages").height() - $("#controls").height() - 20);
		$("#map-panel").css("height", $("#panelATX").height() + 2);
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
		self.marker = null;
		self.mobile = true;

		self.transitMode = ko.observable("DRIVING");

		self.myLoc = ko.observable("");
		self.markers = [];

		self.cdID = ko.observable("0");
		self.psID = ko.observable("0");
		self.psAd = ko.observable("");
		self.psName = ko.observable("");
		self.endDirections = null;

		self.locations = ko.observableArray([]);
		self.selectedLocation = ko.observable();

		self.preOverlay;
		self.preCheck = ko.observable(false);
		this.preCheck.subscribe(function(newValue) {
			this.toggleOverlay("precinct", newValue);
		}, this);
		self.coOverlay;
		self.coCheck = ko.observable(false);
		this.coCheck.subscribe(function(newValue) {
			this.toggleOverlay("city_council", newValue);
		}, this);

		self.motd = ko.observable("Welcome to VoteATX!");

		var geocoder;
		var directionsDisplay;
		var directionsService = new google.maps.DirectionsService();
		// End View Model Data
		/*
		*  View Model Methods
		*/
		// Convert Precinct ID to Address and populate sidebar with Directions
		// TODO: Deal with "Combined Precincts"
		mappViewModel.prototype.getDirections = function() {
			var address = null;
			if (DEBUG)
				console.log("psID: " + self.psAd());

			if (self.transitMode() !== null | "UFO") {
				var request = {
					origin : self.myLoc(),
					destination : self.psAd(),
					travelMode : self.transitMode()
				};
				directionsService.route(request, function(response, status) {
					if (status == google.maps.DirectionsStatus.OK) {
						directionsDisplay.setDirections(response);
						openPanel();
					}
				});
				directionsDisplay.setMap(self.map);
			}
		};

		function openPanel() {
			// If the side panel is not open, transition it to display directions
			if (!$('#map-panel').hasClass('open')) {
				$('#menuToggle').focus();
				$('#menuToggle').click();
			};
		};

		// Transit Mode UFO
		mappViewModel.prototype.modeUFO = function() {
			setTimeout(function() {
				self.transitMode("DRIVING");
				$("#ufo").removeClass("btn-default").addClass("disabled");
			}, 3000);
			console.log("You come from France!");
		};

		function resizeMap() {
			if (self.mobile && $(window).width() > 480) {
				self.mobile = false;
				$('#panelATX').append($('#map-canvas'));
				$("#map-canvas").css("height", $(window).height() - $("#messages").height() - $("#controls").height() - 20);
				$("#map-panel").css("height", $("#panelATX").height() + 2);
				if (DEBUG)
					console.log("resized for !mobile");
			} else if (!self.mobile && $(window).width() < 481) {
				self.mobile = true;
				$("#map-canvas").css("height", "300px");
				$('#collapseMap').append($('#map-canvas'));
				if (DEBUG)
					console.log("resized for mobile");
			} else if ($(window).width() < 481)
				$("#map-canvas").css("height", "300px");
			self.map.panTo(self.marker.getPosition());
		};

		$(window).resize(function() {
			resizeMap();
		});
		// End ViewModel Methods
		/*
		 *  Geolocation
		 */
		function geo_success(position) {
			var latlng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude);
			setPosition(latlng);
			geocoder.geocode({
				'latLng' : latlng
			}, function(results, status) {
				if (status == google.maps.GeocoderStatus.OK) {
					if (results[1]) {
						//self.geoLoc = results[1].formatted_address;
						self.myLoc(results[1].formatted_address);
						//setTimeout(self.getDirections(), 50);
						console.log("located");
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
		/*
		*  Google Maps Methods
		*/
		// Initialize function. Muy Importante.
		function initialize() {
			var mapOptions = {
				zoom : 13,
				center : new google.maps.LatLng(FALLBACK_LAT, FALLBACK_LNG),
				styles : blue,
				mapTypeControl : false
			};

			self.map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
			directionsDisplay = new google.maps.DirectionsRenderer();
			directionsDisplay.setMap(self.map);
			directionsDisplay.setPanel(document.getElementById('directions-panel'));

			self.marker = new google.maps.Marker({
				position : self.map.getCenter(),
				map : self.map,
				draggable : true
			});

			google.maps.event.addListener(self.marker, "dragend", function(event) {

				var point = self.marker.getPosition();
				setPosition(point);
			});

			geocoder = new google.maps.Geocoder();
			initControls();
			resizeMap();

			// TODO: Figure out if this is actually helpful
			google.maps.event.addListenerOnce(self.map, 'idle', function() {
				google.maps.event.trigger(self.map, "resize");
			});

			// Initialize custom controls
			var regionOverlayDiv = document.createElement('div');
			var regionOverlayControl = new RegionOverlayControl(regionOverlayDiv, self.map);

			regionOverlayDiv.index = 1;
			self.map.controls[google.maps.ControlPosition.TOP_RIGHT].push(regionOverlayDiv);
		};
		// Listener for initialize
		google.maps.event.addDomListener(window, 'load', initialize);

		// Pans Map and positions YAH Marker
		/* Overloaded to accept LatLng or (Lat, Lng) */
		function setPosition(latlng, lng) {
			var loc;

			if ( typeof lng !== "undefined") {
				loc = new google.maps.LatLng(latlng, lng);
			} else {
				loc = latlng;
			}
			if (self.map) {
				self.map.panTo(loc);
				self.marker.setPosition(loc);
				directionsDisplay.setMap(null);
				phoneHome(loc);
				geocoder.geocode({
					'latLng' : loc
				}, function(results, status) {
					if (status == google.maps.GeocoderStatus.OK) {
						if (results[1]) {
							self.myLoc(results[1].formatted_address);
						}
					} else {
						console.log("Geocoder failed due to: " + status);
					}
				});
			} else {
				console.log("Map not found! Check MAP_ID configuration.");
			};
		};

		mappViewModel.prototype.toggleOverlay = function(type, bool) {
			var region;
			if (!bool) {
				if(type === "precinct")
					self.preOverlay.setMap(null);
				else self.coOverlay.setMap(null);
					
					return;
			}
			if(type === "precinct")
				region = drawRegion(type, self.psID());
			else region = drawRegion(type, self.cdID());
			if (DEBUG)
				console.log(region);
		};

		google.maps.Map.prototype.clearOverlays = function() {
			for (var i = 0; i < self.markers.length; i++) {
				self.markers[i].setMap(null);
			}
			self.markers = [];
		};
		// End Google Maps Methods

		/*
		*  Server Request and Map Updating
		*/
		// Overloaded - phoneHome(latlng literal) or phoneHome(double lat, double lng)
		function phoneHome(latlng, lng) {
			self.map.clearOverlays();
			var lat;
			if ( typeof lng !== "undefined") {
				lat = latlng;
			} else {
				lat = latlng.lat();
				lng = latlng.lng();
			}
			var url = SVC + SVC1 + lat + SVC2 + lng;

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log(response);

				self.motd(response.message.content);
				switch(response.message.severity) {
				case "WARNING":
					$("#alerts").addClass("alert-warning").removeClass("alert-info");
				}

				self.psID(response.districts.precinct.id);
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
						draggable : false,
					});
					var contentString = '<div id="content">' + '<h2 id="firstHeading" class="firstHeading">' + val.title + '</h1><br/>' + '<div id="bodyContent"><p>' + val.info.replace(regex, "<br/>") + '</p></div></div>';
					var infowindow = new google.maps.InfoWindow({
						maxWidth : 250,
						content : contentString
					});

					// Bind the Info Window to the Marker
					google.maps.event.addListener(marker, 'click', function() {
						infowindow.open(self.map, marker);
						self.psName(response.places[index].location.name);
						self.psAd(response.places[index].location.address + ", " + response.places[index].location.city + ", " + response.places[index].location.state);
					});

					// Now populate the array for the selects
					self.markers.push(marker);
				});
				if (DEBUG)
					console.log(self.locations());
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
			var url = SVC + "/districts/" + type + "/" + id;

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log(response);
				var array = response.region.coordinates[0];
				var polyCoords = [];
				$.each(array, function(index, val) {
					var LatLng = new google.maps.LatLng(val[1], val[0]);
					polyCoords.push(LatLng);
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
						fillOpacity : 0.35
					});
					self.preOverlay.setMap(self.map);
				} else {
					self.coOverlay = new google.maps.Polygon({
						paths : polyCoords,
						strokeColor : '#FFFFF',
						strokeOpacity : 0.8,
						strokeWeight : 2,
						fillColor : '#FFFFFF',
						fillOpacity : 0.35
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
		function initControls() {
			// AutoComplete for Starting Location (You Are Here)
			var input = document.getElementById('startLoc');
			setupAutocomplete(input);
			input = document.getElementById('mobileLoc');
			setupAutocomplete(input);
		};

		function setupAutocomplete(input) {
			// Bounds for AutoComplete
			var defaultBounds = new google.maps.LatLngBounds(new google.maps.LatLng(30.2, -97.9), new google.maps.LatLng(30.5, -97.5));
			var opts = {
				bounds : defaultBounds,
				rankBy : google.maps.places.RankBy.DISTANCE,
				componentRestrictions : {
					country : 'us'
				}
			};

			var autocomplete = new google.maps.places.Autocomplete(input, opts);
			// Listener to respond to AutoComplete
			google.maps.event.addListener(autocomplete, 'place_changed', function() {
				var place = autocomplete.getPlace();
				setPosition(place.geometry.location);
				self.myLoc(place.formatted_address);
			});
		};

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
	};

	ko.applyBindings(new mappViewModel());
});
