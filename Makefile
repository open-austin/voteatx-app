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

# an unfortunate true test in shell quote escaping. this is not the best way to do this.
# the better way is for these vars to not be hard-coded and a config file be used for diff envs.
# also, a js-specific tool for building would be much more ideal.
VOTEATX_SVC_URL_SED_REGEX='s!^(\s*var\s+VOTEATX_SVC\s*=\s*("|'\''))(.*)(("|'\'')\s*;)!\1http://54.191.204.32:1337\4!'
SVC_URL_SED_REGEX='s!^(\s*var\s+SVC\s*=\s*("|'\''))(.*)(("|'\'')\s*;)!\1http://54.191.204.32:1337\4!'
PROD_SSH_DOMAIN=ubuntu@ec2-54-191-204-32.us-west-2.compute.amazonaws.com
DAEMON_START_CMD='NODE_ENV=production /home/ubuntu/.nvm/versions/node/v6.5.0/bin/forever \
	start -a -p /home/ubuntu/ \
	--pidFile=/home/ubuntu/voteatx-app.pid \
	-o /home/ubuntu/voteatx-app.log \
	-e /home/ubuntu/voteatx-app.err \
	-c /home/ubuntu/.nvm/versions/node/v6.5.0/bin/node \
	--workingDir=/var/www/voteatx-app/public \
	--uid "voteatx-app"'
DAEMON_STOP_CMD='/home/ubuntu/.nvm/versions/node/v6.5.0/bin/forever stop voteatx-app'
SSH_OPTIONS=-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i voteatx.pem

# sed out the VOTEATX_SVC url in favor of the prod url.
# the prod url is http://54.191.204.32:1337
# this sed cmd is GNU sed, so mac users, set PATH accordingly
prod_svc_url :
	sed -ri ${VOTEATX_SVC_URL_SED_REGEX} public/js/mappit.js
	sed -ri ${SVC_URL_SED_REGEX} frozen/mappit.js

push : prod_svc_url
	scp -r ${SSH_OPTIONS} public/* ${PROD_SSH_DOMAIN}:/var/www/voteatx-app/public/

start :
	ssh ${SSH_OPTIONS} ${PROD_SSH_DOMAIN} sudo ${DAEMON_START_CMD} /usr/local/bin/http-server -p 80

stop :
	ssh ${SSH_OPTIONS} ${PROD_SSH_DOMAIN} sudo ${DAEMON_STOP_CMD} || echo "ignoring a failure to stop. continuing tasks"

restart : stop start

deploy : stop prod_svc_url push start
