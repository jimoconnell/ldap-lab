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

Choose **1** to start the stack, then **4** to load sample users and groups. Use **7** for connection details and **8** for the web UI login.

## What you get

- **OpenLDAP** (osixia/openldap) on `localhost:389` (LDAP) and `localhost:636` (LDAPS)
- **phpLDAPadmin** on `http://localhost:8086`
- Default domain: `dc=example,dc=com`
- Sample **OUs**: `users`, `groups`, `svc`
- Sample **users**: jim, alice, bob (password: `password`)
- Sample **groups**: developers, ops, engineering (nested)
- **Service account** for binds: `uid=hz-bind,ou=svc,dc=example,dc=com` (password: `bindpassword`)

## Menu options

| Option | Action |
|--------|--------|
| 1 | Start LDAP + UI (Docker Compose up) |
| 2 | Stop stack (down) |
| 3 | Reset stack and **delete volumes** (wipes data) |
| 4 | Load sample users/groups from bootstrap LDIF |
| 5 | Run quick tests (ldapwhoami, ldapsearch) |
| 6 | Show container status |
| 7 | Show connection info (URLs, DNs, passwords) |
| 8 | Show UI login info |
| 9 | Exit |

## Generated files

The script creates a `ldap-lab/` directory in the current working directory (same directory as the script) with:

- `compose.yml` – Docker Compose for LDAP + phpLDAPadmin
- `bootstrap.ldif` – sample users, groups, and service account

These are created on first run if missing. The directory is listed in `.gitignore` so it is not committed.

## License

MIT License. See [LICENSE](LICENSE). Use, modify, and distribute freely.
