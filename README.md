# mailserver

Dockerised mailserver, inspired by https://jan.wildeboer.net/2022/08/Email-1-Postfix-2022/ .

**Prerequisites**
- A server on the internet
- A DNS domain for sending / receiving mails. Multiple domains are supported.

**Features**
- SMTP[s] and IMAP[s] servers, with managesieve for server-side IMAP filtering
- Fully automated set-up based on very few settings, including
  - certificates generation and renewal (on container restart)
  - SPF, DKIM, and DMARC integration
- Fail2Ban to auto-ban offending IP addresses based on mail server log entries
- Basic user handling (add/delete, aliases)
- Monitoring suite (optional), with "landing page" summary dashboard as well as detailed dashboards for SMTP server, IMAP server, Fail2Ban, and DNS sanity

# Quickstart instructions

For detailed set-up and operations instructions please consult the [wiki](https://github.com/t-lo/mailserver/wiki)

First, clone the [repository](https://github.com/t-lo/) or download a [release tarball](https://github.com/t-lo/mailserver/releases).

**Set up server**

1. `cp settings.env.empty settings.env`; edit `settings.env` and fill in:
   ```
   DOMAIN=
   HOSTNAME=
   ADMIN_USER_INITIAL_PASSWORD=
   ADDITIONAL_DOMAINS=
   ```
   If you leave `METRICS=true` also set `GF_SECURITY_ADMIN_PASSWORD=` or you won't be able to log into the metrics website.

   All other settings are set to sane defaults.
   Basic help is provided for all settings; review and update as you see fit.

**Create DNS record for your mail server**

Go to your DNS service provider and create a Host DNS record ("A record") for `HOSTNAME` pointing to your server's IP.
This must be done prior to the mailserver's first run to successfully request letsencrypt certificates for `HOSTNAME`.

**Start server**

The server needs ports 80 for http, 25 and 465 for SMTP(s), 143 and 993 for IMAP, and 4190 for managesieve.
Monitoring needs port 443 for HTTPS.

1. `./start_mailserver.sh` <br/>
   If you left `METRICS=true`, also run `start_monitoring.sh`. <br/>
   Monitoring dashboards can be accessed at `https://<HOSTNAME>/monitoring/`.
   
If ports 80 and 443 are already in use, alternative ports for HTTP and HTTPS can be provided on the command line: `./start_mailserver.sh <HTTP-PORT> <HTTPS-PORT>`
Make sure to configure proxy forwarding on your host so HTTP requests for `HOSTNAME` are forwarded to the mailserver container's custom HTTP port.
See https://github.com/t-lo/mailserver/wiki/Use-custom-ports-for-HTTP---HTTPS for more information.

On first run the server will initialise, request letsencrypt certificates, generate DKIM keys, and generate DH parameters for the mail server's TLS connections.
This can take a few minutes.

Also, a default postmaster account `ADMIN_USER@DOMAIN` will be created.
This account will receive letsencrypt certificate renewal notifications as well as abuse reports from other mailserver operators.
Check the account's inbox regularly.
If you use monitoring you can check the amount of unread admin mails on the home dashboard.
The account's SMTP / IMAP password is `ADMIN_USER_INITIAL_PASSWORD` and can be changed later (see user management below).

**Set up DNS for your domain**

1. Add an MX record to `DOMAIN` and (if applicable) `ADDITIONAL_DOMAINS` and point it to `HOSTNAME`.
2. Basic validation of DNS settings:
   ```shell
   ./dns_check.sh
   ```
   SPF, DMARC, and DKIM checks will fail in this run because these were not set up yet. <br/>
   The script will print out example SPF, DMARC, and DKIM DNS entries to use in the next step.
3. Add SPF, DMARC, and DKIM DNS entries for all domains based on the `dns_check.sh` script output. <br />
   Alternatively, consult the DNS dashboard (if you use monitoring) at `https://HOSTNAME/monitoring/d/dnsy/dns-sanity` - it also has SPF, DMARC, and DKIM records for copy+pasting to your DNS provider.
4. Run the validation script again:
   ```shell
   ./dns_check.sh
   ```
   All checks should now pass. <br/>
   Use https://www.checktls.com/TestReceiver or https://mxtoolbox.com/dnscheck.aspx for more thorough checks.

**Automatically start at boot**

1. Stop the mailserver and (if applicable) the monitoring service.
2. `cp systemd/ /etc/systemd/system/`
3. `systemd daemon-reload`
4. `systemd enable --now mailserver` <br/>
    For monitoring: `systemd enable --now mailserver-monitoring`

If you use custom ports for HTTP and HTTPS don't forget to update mailserver.service and add the ports as positional arguments to `ExecStart=/opt/mailserver/start_mailserver.sh`.

**Manage users and aliases**

User management works transparently for both `DOMAIN` and `ADDITIONAL_DOMAINS`.

1. `./user.sh add meier@entropiesenke.de 12345` add user w/ password `12345`
2. `./user.sh add jens@wombathub.de` add user and auto-generate (and print) password
3. `./user.sh passwd jens@wombathub.de 23456` change jens' password to `23456`.
4. `./user.sh list` list users
5. `./user.sh del jens@wombathub.de` del user `jens@wombathub.de`. Use `.. --purge-inbox ..` to also delete all emails.
6. To manage aliases, edit `_server_workspace_/etc/postfix/valias` (`<alias email>  <domain user>` key value, separated by space), then run `./user.sh update-aliases`.

**Client set-up for mail server users**

1. *Username*: is the `user@domain` name supplied to `user.sh add ...`. Password is the password provided (or generated).
2. SMTP/IMAP server is `HOSTNAME`. <br/>
   SMTP is available via STARTTLS at port 25, and via SSL/TLS at port 465. <br/>
   IMAP is on port 143, IMAPS on 993.

# Contribute
See the [contributing](https://github.com/t-lo/mailserver/wiki#contributing) page of the project's wiki.
