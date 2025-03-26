# Mailman 3 integration for mailserver.

Prerequisites:
- `Metrics=true` to activate the Caddy HTTPS server
- `docker-compose` on the host

This integration relies on the Mailman 3 docker container set-up discussed here: https://asynchronous.in/docker-mailman/ .

Contrary to the default mailserver set-up, it relies on `docker-compose` instead of plain Docker.
The service is configured directly in the docker-compose file `mailman.yaml`.
It will use `_server_workspace_/mailman` for its state.

A Caddy configuration snippet is provided and can be included in the main Caddy HTTPS config.
The mailman integration assumes Monitoring is used and Caddy serves HTTPS.

Integration with Postfix is done via transport maps, relay domains, and virtual alias maps.
The postfix configuration template `_server_workspace_/etc/postfix/main.cf.tmpl` must be updated to include these mappings.

Installation:
1. It is assumend the mailserver is properly configured and has been started at least once, so the configuration files are available at `_server_workspace_`.
2. Copy `mailman.yaml` and `start_mailman.sh` into the repository root.
3. Edit `mailman.yaml` and follow instructions to fill in the placeholders ("TODO:").
   You'll need to create a `mailman@DOMAIN` user on the mailserver for this.
4. Copy `Caddyfile.mailman.inc` to `_server_workspace_/etc/caddy`
5. Edit `Caddyfile.mailman.inc` and follow instructions to activate the include file
6. Edit `_server_workspace_/etc/postfix/main.cf.tmpl` and add the contents of `postfix.main.snippet`
   (see instructions in `postfix.main.snippet`).
7. Copy the `mailman.cfg` config snippet to `_server_workspace_/mailman/core/mailman-extra.cfg` and edit the file to fill in the blanks.
   Copy your mail server's private DKIM signing key to where it was specifiec in ``, likely `_server_workspace_/mailman/core//var/etc/`.
   1. NOTE that Mailman's ARC signature subsystem requires mailserver keys to be in PKCS#1 format.
      Newer openssl versions produce PKCS#8 keys, leading to this error:
      ```
          Traceback (most recent call last):
              File "/opt/mailman/lib/python3.7/site-packages/dkim/crypto.py", line 140, in parse_private_key
                pka = asn1_parse(ASN1_RSAPrivateKey, data)
              File "/opt/mailman/lib/python3.7/site-packages/dkim/asn1.py", line 85, in asn1_parse
                r.append(asn1_parse(t[1], data[i:i+length]))
              File "/opt/mailman/lib/python3.7/site-packages/dkim/asn1.py", line 92, in asn1_parse
                "Unexpected tag (got %02x, expecting %02x)" % (tag, t[0]))
            dkim.asn1.ASN1FormatError: Unexpected tag (got 30, expecting 02)
        ```
        To convert a private key from one format into the other, use
        ```
        openssl rsa -in pkcs8key.key -traditional -out pkcs1key.key
        ```

Restart the mailserver.

Now start mailman for a first test run via `docker-compose -f mailman.yaml up` in the repository root.

You should be able to log in to the web interface at `https://HOSTNAME/`.
    1. First, you'll need to authenticate with the username (default "mailman") and password you used
        to generate the password hash for the caddyfile in step 4.
    2. Second, use the "forgot password" feature to set your initial mailman admin user password for the
       `MAILMAN_ADMIN_USER` you've set in `mailman.yaml` (step 3).

To start at host system boot,
    1. Stop the docker-compose set-up if you've started it from the command line.
    1. Copy `mailserver-mailman.service` to `/etc/systemd/system/`.
    2. Run `systemctl daemon-reload`.
    3. Run `systemctl enable --now mailserver-mailman.service`.
