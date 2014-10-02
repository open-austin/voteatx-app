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

		self.spinner(false);

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
	if (type === "precinct") {
		if (self.preOverlay) {
			self.preOverlay.setMap(null);
		}
	} else {
		if (self.coOverlay) {
			self.coOverlay.setMap(null);
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
 * KOut+BStrap Integration
 */

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