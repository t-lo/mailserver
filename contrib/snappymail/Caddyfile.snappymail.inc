#
# Snappymail HTTPS proxy include snippet
#
# This include assumes that you are using Monitoring.
# Monitoring activates Caddy as a HTTPS server which this include
#  will use to serve the Snappymail web mail interface.
#
# See https://snappymail.eu/ for more information on SnappyMail, and
#     https://github.com/the-djmaze/snappymail for the github repo
#      (including docker image files).
#

# 1. Copy to _server_workspace_/etc/caddy
# 2. Edit _server_workspace_/etc/caddy/Caddyfile.https.tmpl and add to the "imports" section:
#     import /etc/caddy/Caddyfile.snappymail.inc
# 3. Run "systemctl restart mailserver"

# INCLUDE START

	handle_path /webmail/* {
		request_header -authorization
		reverse_proxy mailserver-webmail:8888 {
			header_up Host {host}
			header_up X-Forwarded-Proto https
			header_up X-Real-IP {remote_host}
		}
	}


# INCLUDE END
