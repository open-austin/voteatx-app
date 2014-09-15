VoteATX App
===========

This app uses Google Maps, Bootstrap, and Knockout.js to display election information for citizens of Travis County (Austin), TX.  It is built off of the <a href="https://github.com/open-austin/voteatx-svc"> VoteATX-svc backend.

To make it work for another County/City: 
<ul><li>Properly configure a new service (voteatx-svc) for that location;</li>
<li>Update the configuration constants at the top of the mappit.js file to point to the service;</li>
<li>Update the config constants to provide a new fallback lat/lon, as well as new bounds for autocomplete recommendations;</li>
<li>Update the about panel information in index.html to provide information relevant to the new voting locale.</li>
</ul>
