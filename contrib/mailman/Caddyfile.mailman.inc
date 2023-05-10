#
# Mailman HTTPS proxy include snippet
#

# This include assumes that you are using Monitoring.
# Monitoring activates Caddy as a HTTPS server which this include
#  will use to serve the mailman web interface.

# 1. Copy to _server_workspace/etc/caddy
# 2. Generate a password hash for basic auth and replace <PASSWORD_HASH> below:
#      docker run --rm --entrypoint /usr/sbin/caddy ghcr.io/t-lo/mailserver hash-password --plaintext <PASSWORD>
#    Note down the password - this is for HTTP basic authentication with username "mailman".
# 3. Edit /host/etc/caddy/Caddyfile.https.tmpl and add to the "imports" section:
#     import /host/etc/caddy/Caddyfile.mailman.inc


# Include start

        # Disable sign-up by default. Remove this section to enable sign-up.
        handle /accounts/signup/* {
                respond * 403 {
                        body "Sign-up is disabled. Edit Caddyfile.mailman.inc to change this."
                        close
                }
        }

        # Mild protection via Basic authentication. Make up a user name (or go with 'mailman')
        #  and generate a password hash via 
        # docker run --rm --entrypoint /usr/sbin/caddy ghcr.io/t-lo/mailserver hash-password --plaintext <PASSWORD>
        basicauth {
                mailman <PASSWORD_HASH>
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
