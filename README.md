# mailserver

Dockerised mailserver, inspired by https://jan.wildeboer.net/2022/08/Email-1-Postfix-2022/ .

# How to use

To get started, you'll need an internet-connected server as well as a DNS name pointing to it.
DNS is a requirement for getting letsencrypt certificates.

## TL;DR

**Set up server**

1. Create `settings.env` and set
   ```
   DOMAIN=
   HOSTNAME=
   ADMIN_EMAIL=
   ADDITIONAL_DOMAINS=
   ```
2. `mkdir _server_workspace_`


**Create DNS entries for your mail server**

1. Create an A record for `HOSTNAME` pointing to your server's public IP, and a (reverse-DNS) PTR record for your server's public IP to resolve to `HOSTNAME`.
2. Add an MX record to `DOMAIN` and (if applicable) `ADDITIONAL_DOMAINS` and point it to `HOSTNAME`.
3. Validate DNS settings:
   ```shell
   docker run --rm -ti --entrypoint /dns_sanity.sh --env-file settings.env --name mailserver-sanitycheck ghcr.io/t-lo/mailserver
   ```


**Start server**

1. `docker run --rm -ti -p 80:80 -p 25:25 -p 465:465 -p 143:143 -p 993:993 -v $(pwd)/_server_workspace_:/host --env-file settings.env --name my-mailserver ghcr.io/t-lo/mailserver`


**Manage users and aliases**

1. `./user.sh add meier@entropiesenke.de 12345` add user w/ password `12345`
2. `./user.sh add jens@wombathub.de` add user and auto-generate (and print) password
3. `./user.sh list` list users
4. `./user.sh del jens@wombathub.de` del user `jens@wombathub.de`. Use `.. --purge-inbox ..` to also delete all emails.
5. Edit `_server_workspace_/etc/postfix/valias` (`<alias email>  <domain user>` key value, separated by space), then run `./user.sh update-aliases`.


**Client set-up for mail server users**

1. *Username*: is the `user@domain` name supplied to `user.sh add ...`. Password is the password provided (or generated).
2. SMTP/IMAP server is `HOSTNAME`.
   SMTP is available via STARTTLS at port 25, and via SSL/TLS at port 465.
   IMAP is on port 143, IMAPS on 993.

## Set up your mail server

Create a file `settings.env` (e.g. from the skeleton `settings.env.empty` provided with this repo); then fill in the following.
It is recommended to pick a unique DNS name for your mailserver - like `mail.mydomain.tld` - to avoid a number of edge cases and pitfalls.
Note that your mail server `HOSTNAME` does not necessarily need to be a member of `DOMAIN` - `mail.t-lo.net` can happily serve mails for users of domain `wombathub.de`.
```shell
# Name of your main email domain. Likely (but not necessarily) the domain part of your hostname.
DOMAIN=

# Hostname of the mail server. A valid DNS name entry must exist and point to this server's IP address.
HOSTNAME=

# Administrative email address for Letsencrypt certificate requests.
ADMIN_EMAIL=

# Comma-separated list of additiona domain names for which this server will accept mail.
# Also known as "virtual domains".
ADDITIONAL_DOMAINS=
```

**NOTE** this is a docker environment file. Do not use quotation marks around values as these will become part of the value. <br/>
Use e.g. `HOSTNAME=mymail.mydomain.tld`, not `HOSTNAME="mymail.mydomain.tld"`.

## Create a work directory for the mail server container

Stateful data like mailboxes, user accounts, generated mail server configurations, and web root with letsencrypt certificates will be stored here.

```shell
$ mkdir _server_workspace_
```

## Set up DNS for your mailserver

A correct and complete DNS setup is important not only for your mailserver to be found but also for other mailservers to trust your server.

**A record and reverse-DNS PTR**

First, make you're you have an A record (a generic server entry) for your server's `HOSTNAME` pointing to your server's public IP address.
This is commonly i(generalised) referred to as "DNS entry".
If you run a `ping -n $HOSTNAME` your mail server's IP should be pinged.

**NOTE** The A record should be created before the mail server is started for the first time.
Letsencrypt requires a correct A record to be set in order to grant certificates.

Complementarily, create a PTR for your server's public IP address to `HOSTNAME`.
When sending email, other mail servers will look up your server's A record, reverse-DNS resolve the IP address via the PTR record, and compare the results.

**MX records for all domains served by the mailserver**

Also, every domain served by the mailserver (both the main `DOMAIN` as well as additional domains listed in `ADDITIONAL_DOMAINS`) 

If A and PTR do not match it is more likey that mails sent from your server will end up in SPAM - or outright rejected.

**Test your DNS set-up**

The repository supplies a script to check most basic DNS settings. More complex checks are available via e.g. https://mxtoolbox.com/dnscheck.aspx
```shell
docker run --rm -ti --entrypoint /dns_sanity.sh --env-file settings.env --name mailserver-sanitycheck ghcr.io/t-lo/mailserver
```

## Start the mail server container

Start the server:
```shell
$ docker run --rm -ti -p 80:80 -p 25:25 -p 465:465 -p 143:143 -p 993:993 -v $(pwd)/_server_workspace_:/host --env-file settings.env --name my-mailserver ghcr.io/t-lo/mailserver
```

In the above command we allow the following TCP ports for the mail server container:
- 80: HTTP, for letsencrypt's www challenges. We'll assume you do not have a webserver running on your mailserver (see further below if you do).
- 25, 465: SMTP and SMTPS
- 143, 993: IMAP and IMAPS

Furthermore, we bind the local `_server_workspace_` directory into the container for all stateful data, and we pass our environment file with the server settings.

Initial start-up can take a few minutes since it calculates DH parameters for postfix' TLS connections to other SMTP servers.
Subsequent start-ups will be much faster.
On start-up, the server will request letsencrypt certificates for the mail service and store these in `_server_workspace_/etc/letsencrypt`.

## Add or delete users, create aliases

The container ships a few comfort scripts for adding and removing users.
These scripts reside in the repo's main directory and call implementations inside the container.
The counterparts inside the container reside in th repo's `scripts/` directory and are added to the container at build time (see `Dockerfile`).

### Add a new user

```shell
$ ./user.sh add jens@wombathub.de
Created user 'jens@wombathub.de', generated password is:'0sw;eZxqh(M6mmjlnqu;'.
```
**NOTE** Password is *within* the single quotes (`'`). The single quotes are *not* part of the password.

Create users for any of the DOMAIN or ADDITIONAL_DOMAINS you've defined in the server settings.
For the user's IMAP and SMTP access you can either supply a password or have the script auto-generate one.
In the latter case the password is printed after the user has been generated.

To add user "meier" with password "12345" to domain "entropiesenke.de", run
```shell
$ ./user.sh add meier@entropiesenke.de 12345
Created user 'meier@entropiesenke.de' with password provided.
```

## List all users

```shell
$ ./user.sh list
```

Displays a list of all users and their inbox sizes.

### Delete a user

```shell
$ ./user.sh del jens@wombathub.de
Deleted 'jens@wombathub.de'.
```

This removes a user and prevents them from accessing the server.
Optionally, the email inbox (all of the user's emails) can also be deleted.
If the inbox is not deleted, the user can later be re-created (see `add_user.sh`) to re-enable access.

```shell
$ ./user.sh del --purge-inbox jens@wombathub.de
Deleted 'jens@wombathub.de' and purged mail/inboxes/wombathub.de/jens@wombathub.de.
```

### Manage aliases

User aliases are maintained in `_server_workspace_/etc/postfix/valias` and can be edited directly.

The aliases file's structure is very simple. Each line defines one alias:
```
[alias-source-email] [alias-target-user]
```

While alias sources are complete email addresses - `user@domain` and all domains can be used, alias destinations are limited to user accounts on the mail server's main `DOMAIN`.
Assuming `DOMAIN=wombathub.de` and `ADDITIONAL_DOMAINS=entropiesenke.de`, this example
```
postmaster@entropiesenke.de karl
abuse@entropiesenke.de karl
```
sets up account `karl@wombathub.de` to also receive email for `abuse@entropiesenke.de` and `postmaster@entropiesenke.de`.
The account `karl@wombathub.de` must of course exist for this to work.

**Update the aliases after changing `_server_workspace_/etc/postfix/valias` by running**
```
$ ./user.sh update-aliases
```

### Mail client settings

**Server settings**

The server supports plain SMTP (enforces STARTTLS), SMTP over SSL, IMAP, and IMAP over SSL.
- The mail server (for both sending and receiving) is `HOSTNAME`.
- SMTP:
  - Port 25 w/ STARTTLS
  - Port 465 w/ SSL/TLS
- IMAP:
  - Port 143 (STARTTLS)
  - Port 993 w/ SSL/TLS

Either "plain" or "login" login is supported. Username is the full `user@domain` name supplied to `user.sh add ...`. Password is the password provided (or generated).

## Issues and workarounds

### I'm running a webserver on the mailserver host and cannot give port 80 to the mailserver container

In this scenario, a web server runs on the host that also runs the mailserver container. The container caannot use port 80 because it is used by the host's webserver.
To work around this issue and still have the mailserver container handle the mailserver's certificates, add a proxy configuration to the hosts's webserver.
The proxy (i.e. the host's webserver) will accept connections on port 80 for the mailserver's `HOSTNAME` and forward the connection to the mailserver container.
For this to work, the mailserver container needs to map its HTTP port to something else than port 80.

**Without proxy**
```
           host webserver                   mailserver container
    .--------------------------.        .--------------------------.
--->|:80   www.mydomain.tld    |     ??????        :-(             |
    `--------------------------´        `--------------------------´

```

**With proxy**
```
           host webserver          
    .------------------------------.
--->|:80   www.mydomain.tld        |
    |     mail.mydomain.tld :12345--.      mailserver container
     `----------------------------´ |   .--------------------------.
                                    `-->|:12345     8-D            |
                                        `--------------------------´
```

Here's a very simple proxy definition for the above, for Apache Foundation's httpd:
```xml
<VirtualHost *:80>
        ServerName mail.mydomain.tld.
        ProxyPass / http://127.0.0.1:12345/
        ProxyPassReverse / http://127.0.0.1:12345/
        ProxyPreserveHost on
</VirtualHost>
```
Put this in a separate `.conf` file in `/etc/httpd/conf.d/` and run `sudo systemd reload httpd` (Fedora, Red Hat, CentOS, etc.) / `/etc/apache/sites-enabled/` (Debian, Ubuntu, etc.) and run `sudo systemd reload apache` to activate.

Then, make sure to map the container's port 80 to the proxy's port 12345, and you're good! 
```shell
$ docker run --rm -ti -p 12345:80 -p 25:25 -p 465:465 -p 143:143 -p 993:993 -v $(pwd)/_server_workspace_:/host --env-file settings.env --name my-mailserver ghcr.io/t-lo/mailserver
```

# Build the container

A `Dockerfile` is provided with this repo. (Re-)Build the container by issuing
```
$ docker build -t myemailserver .
```

Then run your build:
```
docker run --rm -ti -p 80:80 -p 25:25 -p 465:465 -p 143:143 -p 993:993 -v $(pwd)/_server_workspace_:/host --env-file settings.env --name my-mailserver myemailserver
```
