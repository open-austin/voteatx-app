$(document).ready(function() {

	function mappViewModel() {
		// Configuration
		var DEBUG = true;
		var MAP_ID = 'map_canvas';
		var FALLBACK_LAT = 30.2649;
		var FALLBACK_LNG = -97.7470;
		/* This is the path to the JSON file with data for the election day polling stations
		 * Expected keys: Precinct, Combined Pcts., Name, Address, City, Zip Code, Start Time, End Time, Latitude, Longitude
		 */
		var MAIN_LAYER = "json/ps.json";
		var SVC1 = "http://svc.voteatx.us/search?latitude=";
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

		/*
		 *  View Model Data
		 */
		var self = this;

		self.map = null;
		self.marker = null;
		self.mobile = true;

		self.chosenLayer = ko.observable();

		self.markers = ko.observableArray();

		self.transitMode = ko.observable("DRIVING");

		self.myLoc = ko.observable("");
		self.geoLoc = null;

		self.cdID = ko.observable("0");
		self.psID = ko.observable("0");
		self.psAd = ko.observable("");
		self.psName = ko.observable("");
		self.endDirections = null;

		self.preMap = [];

		self.svc_endpoint = "http://voteatx.us/svc/search";

		var geocoder;
		var directionsDisplay;
		var directionsService = new google.maps.DirectionsService();

		/*
		*  View Model Methods
		*/
		// Convert Precinct ID to Address and populate sidebar with Directions
		// TODO: Deal with "Combined Precincts"
		mappViewModel.prototype.getDirections = function() {
			var address = null;
			if (DEBUG)
				console.log("psID: " + self.psID());

			if (self.transitMode() !== null | "UFO") {
				var request = {
					origin : self.myLoc(),
					destination : self.psName(),
					travelMode : self.transitMode()
				};
				directionsService.route(request, function(response, status) {
					if (status == google.maps.DirectionsStatus.OK) {
						directionsDisplay.setDirections(response);
						openPanel();
					}
				});
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

		// Begin Geolocation
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
						setTimeout(self.getDirections(), 50);
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

		// Google Maps Methods
		function initialize() {
			var mapOptions = {
				zoom : 13,
				center : new google.maps.LatLng(FALLBACK_LAT, FALLBACK_LNG),
				styles : blue
			};

			self.map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
			directionsDisplay = new google.maps.DirectionsRenderer();
			directionsDisplay.setMap(self.map);
			directionsDisplay.setPanel(document.getElementById('directions-panel'));

			self.marker = new google.maps.Marker({
				position : self.map.getCenter(),
				map : self.map,
				draggable : false
			});

			geocoder = new google.maps.Geocoder();
			initControls();
			resizeMap();

			google.maps.event.addListenerOnce(self.map, 'idle', function() {
				google.maps.event.trigger(self.map, "resize");
			});
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
			if (DEBUG)
				console.log(loc);
			if (self.map) {
				self.map.panTo(loc);
				self.marker.setPosition(loc);
				phoneHome(loc);
			} else {
				console.log("Map not found! Check MAP_ID configuration.");
			};
		};

		

		/*
		*  Server Request and Map Updating
		*/
		// Overloaded - phoneHome(latlng literal) or phoneHome(double lat, double lng)
		function phoneHome(latlng, lng) {
			var lat;
			if ( typeof lng !== "undefined") {
				lat = latlng;
			} else {
				lat = latlng.lat();
				lng = latlng.lng();
			}
			var url = SVC1 + lat + SVC2 + lng;

			// Service response here
			function jsonpCallback(response) {
				if (DEBUG)
					console.log(response);

				self.psID(response.districts.precinct.id);
				self.cdID(response.districts.city_council.id);
				self.psName(response.places[0].location.name + " " + response.places[0].location.zip);
				var regex = new RegExp("\\n", "g");

				$.each(response.places, function(index,val){
					var mLatLng = new google.maps.LatLng(val.location.latitude, val.location.longitude);
					var iconPath = "mapicons/icon_vote";
					switch(val.type){
						case "EARLY_VOTING_FIXED":
							iconPath+="_early";
							break;
						case "EARLY_VOTING_MOBILE":
							iconPath+="_mobile";
							break;
					}
					
					if(!val.is_open)
						iconPath+="_closed";
						
					iconPath+=".png";
					
					var icon = new google.maps.MarkerImage(iconPath);
					var marker = new google.maps.Marker({
						position : mLatLng,
						map : self.map,
						icon : icon,
						draggable : false,
					});
					var contentString = '<div id="content">' + '<h2 id="firstHeading" class="firstHeading">' + val.title + '</h1><br/>' + '<div id="bodyContent"><p>' + val.info.replace(regex, "<br/>") + '</p></div></div>';
					var infowindow = new google.maps.InfoWindow({
						content : contentString
					});

					// Bind the Info Window to the Marker
					google.maps.event.addListener(marker, 'click', function() {
						infowindow.open(self.map, marker);
					});
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
