# Snappymail webmail integration for mailserver.

Prerequisites:
- `Metrics=true` to activate the Caddy HTTPS server

This integrates the Snappymail web mail client to Mailserver.
The web mail client runs on the mailserver and is served via
`https://<mailserver-host>/webmail/`. While it has the mailserver's domain and aliases
enabled by default, administrators may add arbitrary additional domains.

A Caddy configuration snippet is provided and must be included in the main Caddy HTTPS config.
The Snappymail integration assumes Monitoring is enabled and Caddy serves HTTPS.

Installation:
    1. It is assumend the mailserver is properly configured and has been started at least once, so the configuration files are available at `_server_workspace_`.
    2. Copy `Caddyfile.snappymail.inc` to `_server_workspace_/etc/caddy`
    3. Edit `Caddyfile.https` and add / uncomment the line
       `import /etc/caddy/Caddyfile.snappymail.inc`.
       Note that this include should reside _above_ the mailman include if
       the mailman contrib is also used.

Restart the mailserver to activate the changes.

To start the webmail interface:
    1. Copy `mailserver-snappymail.service` to `/etc/systemd/system/`.
    2. Run `systemctl daemon-reload`.
    3. Run `systemctl enable --now mailserver-snappymail.service`.

## First-time set-up

All non-volatile data and settings are stored in
`_server_workspace_/snappymail/`.

Snappymail's admin interface is available at
`https://<mailserver-host>/webmail/?admin`. The initial login is `admin`; the
initial admin password is randomly generated at first start and stored in
`_server_workspace_/snappymail/_data_/_default_/admin_password.txt`.

**It is strongly recommended to log into the admin web interface and change the
password after installation.** The admin interface will display a warning and a
quick-link to the password section as long as the initial password is in use.

## Regular use

After the webmail container started you can start using the web interface at
  `https://<mailserver-host>/webmail`.
Snappymail transparently uses the server's IMAP authentication, i.e. mailserver
users authenticate with their email account credentials.
