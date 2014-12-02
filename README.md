# VoteATX App

This app uses Google Maps, Bootstrap, and Knockout.js to display election information for citizens of Travis County (Austin), TX.  It is built off of the <a href="https://github.com/open-austin/voteatx-svc">voteatx-svc backend</a>.

To make it work for another County/City: 
* Properly configure a new service (voteatx-svc) for that location
* Update the configuration constants at the top of the mappit.js file to point to the service
* Update the config constants to provide a new fallback lat/lon, as well as new bounds for autocomplete recommendations
* Update the about panel information in index.html to provide information relevant to the new voting locale

## Contributors

* Designed and implemented by Andrew Vickers
* Graphics by Gail Maynard
* Other contributors: Chip Rosenthal, Alvaro Montoro

