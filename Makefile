#
# There are two index files:
# * index-local.html - Retrieves static assets from local site.
# * index-cdn.html - Retrieves static assets from CDN.
#
# Local test and debug may be performed with "index-local.html".
# For production capacity, "index-cdn.html" may be used.
#
# This Makefile generates "index-cdn.html" from "index-local.html".
#

all : public/index-cdn.html

public/index-cdn.html : public/index-local.html 
	sed -e '/<head>/a <base href="http://s3-us-west-2.amazonaws.com/voteatx-app/public/index.html" />' $< > $@

