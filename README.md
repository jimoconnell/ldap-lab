# ldap-lab

A small local LDAP lab for testing and development. Runs **OpenLDAP** and **phpLDAPadmin** via Docker Compose, with a menu-driven script to start/stop, load sample data, and run quick LDAP checks.

## Requirements

- **Docker** and **Docker Compose** (plugin or standalone `docker-compose`)
- Bash

Optional: **whiptail** for a TUI menu (otherwise a simple text menu is used).

## Quick start

```bash
./ldap-lab.sh
```

Choose **1** to start the stack, then **4** to load sample users and groups. Use **7** for connection details. Use **8** to open the web UI in your browser (or **9** to see the UI URL and guest-mode hint).

## What you get

- **OpenLDAP** (osixia/openldap) on `localhost:389` (LDAP) and `localhost:636` (LDAPS)
- **phpLDAPadmin** (v2) at `http://localhost:8086` — see [Web UI](#web-ui-phpldapadmin) below
- Default domain: `dc=example,dc=com`
- Sample **OUs**: `users`, `groups`, `svc`
- Sample **users**: jim, alice, bob (password: `password`)
- Sample **groups**: developers, ops, engineering (nested)
- **Service account** for binds: `uid=hz-bind,ou=svc,dc=example,dc=com` (password: `bindpassword`)

## Menu options

| # | Action |
|---|--------|
| 1 | Start LDAP + UI |
| 2 | Stop (down) |
| 3 | Reset (down -v, nukes data) |
| 4 | Load sample users and groups (LDIF) |
| 5 | Run quick tests (ldapwhoami, ldapsearch) |
| 6 | Status |
| 7 | Show connection info |
| 8 | Open LDAP UI in browser |
| 9 | UI login info |
| 10 | Exit |

## Web UI (phpLDAPadmin)

The UI is at **http://localhost:8086**. From the menu, **8** opens that URL in your default browser; **9** prints the URL and a short hint.

The UI runs in **guest mode**: it is already connected as `cn=admin,dc=example,dc=com`. There is no login form — open the URL and you can browse and edit the directory. This avoids the rootdn login limitation in phpLDAPadmin v2.

## Generated files

The script creates a `ldap-lab/` directory in the current working directory (same directory as the script) with:

- `compose.yml` – Docker Compose for LDAP + phpLDAPadmin
- `bootstrap.ldif` – sample users, groups, and service account

The script overwrites `compose.yml` on every run; `bootstrap.ldif` is only created if missing. The directory is listed in `.gitignore` so it is not committed.

## License

MIT License. See [LICENSE](LICENSE). Use, modify, and distribute freely.
