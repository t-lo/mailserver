#
# Mailman HTTPS proxy include snippet
#
#
# This include assumes that you are using Monitoring.
# Monitoring activates Caddy as a HTTPS server which this include
#  will use to serve the mailman web interface.
#
# See https://docs.mailman3.org/en/latest/ for more information on mailman;
#     https://asynchronous.in/docker-mailman/ for the docker set-up, and
#     https://github.com/maxking/docker-mailman for the docker images github repo.
#
# 1. Copy to _server_workspace_/etc/caddy
# 2. Generate a password hash for basic auth and replace <PASSWORD_HASH> below:
#      docker run --rm --entrypoint /usr/sbin/caddy ghcr.io/t-lo/mailserver hash-password --plaintext <PASSWORD>
#    Note down the password - this is for HTTP basic authentication with username "mailman".
# 3. Edit _server_workspace_/etc/caddy/Caddyfile.https.tmpl and add to the "imports" section:
#     import /etc/caddy/Caddyfile.mailman.inc
# 4. Run "systemctl restart mailserver"

# Include start

        # Disable sign-up by default. Remove this section to enable sign-up.
        handle /accounts/signup/* {
                respond * 403 {
                        body "Sign-up is disabled. Edit Caddyfile.mailman.inc to change this."
                        close
                }
        }

	# exclude Grafana from mailman's basic auth since it ships its own auth
	@auth {
		not path /monitoring*
		not path /webmail*
	}

        # Mild protection via Basic authentication. Defaults to user "mailman", pass "supersecret".
        #  and generate a password hash via 
        # docker run --rm --entrypoint /usr/sbin/caddy ghcr.io/t-lo/mailserver hash-password --plaintext <PASSWORD>
        basicauth @auth {
                mailman $2a$14$qBxgji2SnzLz8TDnFlEGJOOYhFqVFbE1QQrIGYTXErQnt8g6H6OdS
        }

        handle /static/* {
                uri strip_prefix /static
                file_server {
                        root /host/mailman/web/static
                }
        }

        handle {
                reverse_proxy mailman-web:8000 {
                        header_up X-Forwarded-Proto https
                }
        }

# Include end
