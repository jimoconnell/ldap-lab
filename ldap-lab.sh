#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jim O'Connell
set -euo pipefail

APP_NAME="ldap-lab"
WORKDIR="${PWD}/${APP_NAME}"
COMPOSE_FILE="${WORKDIR}/compose.yml"
LDIF_FILE="${WORKDIR}/bootstrap.ldif"

LDAP_DOMAIN="example.com"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_ORG="Test Org"
LDAP_ADMIN_PASSWORD="admin"

PHPLDAPADMIN_PORT="8086"
LDAP_PORT="389"
LDAPS_PORT="636"
# Fixed APP_KEY for lab sessions (phpLDAPadmin v2); replace in production
PHPLDAPADMIN_APP_KEY="base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# ---------------------------
# Helpers
# ---------------------------
have() { command -v "$1" >/dev/null 2>&1; }

compose_cmd() {
  if have docker && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return 0
  fi
  if have docker-compose; then
    echo "docker-compose"
    return 0
  fi
  return 1
}

ensure_workdir() {
  mkdir -p "${WORKDIR}"

  cat > "${COMPOSE_FILE}" <<YAML
services:
  ldap:
    image: osixia/openldap:1.5.0
    container_name: test-ldap
    environment:
      LDAP_ORGANISATION: "${LDAP_ORG}"
      LDAP_DOMAIN: "${LDAP_DOMAIN}"
      LDAP_ADMIN_PASSWORD: "${LDAP_ADMIN_PASSWORD}"
    ports:
      - "${LDAP_PORT}:389"
      - "${LDAPS_PORT}:636"
    volumes:
      - ldap_data:/var/lib/ldap
      - ldap_config:/etc/ldap/slapd.d

  ldap-ui:
    image: phpldapadmin/phpldapadmin:2.0.0
    container_name: test-ldap-ui
    environment:
      LDAP_HOST: "ldap"
      LDAP_BASE_DN: "${LDAP_BASE_DN}"
      LDAP_USERNAME: "cn=admin,${LDAP_BASE_DN}"
      LDAP_PASSWORD: "${LDAP_ADMIN_PASSWORD}"
      LDAP_ALLOW_GUEST: "true"
      APP_KEY: "${PHPLDAPADMIN_APP_KEY}"
    depends_on:
      - ldap
    ports:
      - "${PHPLDAPADMIN_PORT}:8080"

volumes:
  ldap_data:
  ldap_config:
YAML

  if [[ ! -f "${LDIF_FILE}" ]]; then
    cat > "${LDIF_FILE}" <<'LDIF'
# Base OUs
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups

dn: ou=svc,dc=example,dc=com
objectClass: organizationalUnit
ou: svc

# Users
dn: uid=jim,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
uid: jim
cn: Jim Test
sn: Test
mail: jim@example.com
userPassword: password

dn: uid=alice,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
uid: alice
cn: Alice Test
sn: Test
mail: alice@example.com
userPassword: password

dn: uid=bob,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
uid: bob
cn: Bob Test
sn: Test
mail: bob@example.com
userPassword: password

# Groups (with nesting)
dn: cn=developers,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: developers
member: uid=jim,ou=users,dc=example,dc=com
member: uid=alice,ou=users,dc=example,dc=com

dn: cn=ops,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: ops
member: uid=bob,ou=users,dc=example,dc=com

dn: cn=engineering,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: engineering
member: cn=developers,ou=groups,dc=example,dc=com
member: cn=ops,ou=groups,dc=example,dc=com

# Service account (for binds)
dn: uid=hz-bind,ou=svc,dc=example,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
uid: hz-bind
cn: Hazelcast Bind User
userPassword: bindpassword
LDIF
  fi
}

info_text() {
  cat <<EOF
LDAP URL:      ldap://localhost:${LDAP_PORT}
LDAPS URL:     ldaps://localhost:${LDAPS_PORT}

Base DN:       ${LDAP_BASE_DN}
Admin DN:      cn=admin,${LDAP_BASE_DN}
Admin pass:    ${LDAP_ADMIN_PASSWORD}

Bind DN:       uid=hz-bind,ou=svc,${LDAP_BASE_DN}
Bind pass:     bindpassword

Users:
  uid=jim,ou=users,${LDAP_BASE_DN}      password
  uid=alice,ou=users,${LDAP_BASE_DN}    password
  uid=bob,ou=users,${LDAP_BASE_DN}      password

Groups OU:     ou=groups,${LDAP_BASE_DN}
Nested group:  cn=engineering contains developers and ops

UI:            http://localhost:${PHPLDAPADMIN_PORT} (guest mode: no login)
EOF
}

start_stack() {
  local cc
  cc="$(compose_cmd)" || { echo "Error: docker compose (or docker-compose) not found"; exit 1; }
  (cd "${WORKDIR}" && ${cc} up -d)
}

stop_stack() {
  local cc
  cc="$(compose_cmd)" || { echo "Error: docker compose (or docker-compose) not found"; exit 1; }
  (cd "${WORKDIR}" && ${cc} down)
}

reset_stack() {
  local cc
  cc="$(compose_cmd)" || { echo "Error: docker compose (or docker-compose) not found"; exit 1; }
  (cd "${WORKDIR}" && ${cc} down -v)
}

stack_status() {
  local cc
  cc="$(compose_cmd)" || { echo "Error: docker compose (or docker-compose) not found"; exit 1; }
  (cd "${WORKDIR}" && ${cc} ps)
}

wait_for_ldap() {
  # Wait until slapd is accepting connections inside the container
  local tries=60
  while (( tries > 0 )); do
    if docker exec test-ldap bash -lc "ldapwhoami -x -H ldap://localhost:389 -D 'cn=admin,${LDAP_BASE_DN}' -w '${LDAP_ADMIN_PASSWORD}'" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    tries=$((tries - 1))
  done
  return 1
}
open_browser() {
  local url="$1"

  if command -v open >/dev/null 2>&1; then
    # macOS
    open "$url"
  elif command -v xdg-open >/dev/null 2>&1; then
    # Linux
    xdg-open "$url"
  elif command -v wslview >/dev/null 2>&1; then
    # WSL
    wslview "$url"
  else
    echo "No known browser opener found."
    echo "Open manually: $url"
  fi
}
open_ui() {
  local url="http://localhost:${PHPLDAPADMIN_PORT}"
  echo "Opening $url"
  open_browser "$url"
}
load_sample_data() {
  if ! docker ps --format '{{.Names}}' | grep -qx "test-ldap"; then
    echo "LDAP container not running. Start stack first."
    return 1
  fi

  if ! wait_for_ldap; then
    echo "LDAP did not become ready in time."
    return 1
  fi

  docker exec -i test-ldap bash -lc \
    "ldapadd -x -H ldap://localhost:389 -D 'cn=admin,${LDAP_BASE_DN}' -w '${LDAP_ADMIN_PASSWORD}'" \
    < "${LDIF_FILE}" || true

  echo "Loaded (or attempted to load) sample LDIF: ${LDIF_FILE}"
  echo "If entries already exist, LDAP will report errors, that is expected."
}

test_searches() {
  if ! docker ps --format '{{.Names}}' | grep -qx "test-ldap"; then
    echo "LDAP container not running. Start stack first."
    return 1
  fi

  if ! wait_for_ldap; then
    echo "LDAP did not become ready in time."
    return 1
  fi

  echo
  echo "[1] Who am I (admin bind)"
  docker exec test-ldap bash -lc \
    "ldapwhoami -x -H ldap://localhost:389 -D 'cn=admin,${LDAP_BASE_DN}' -w '${LDAP_ADMIN_PASSWORD}'" || true

  echo
  echo "[2] Search for users under ou=users"
  docker exec test-ldap bash -lc \
    "ldapsearch -x -H ldap://localhost:389 -D 'cn=admin,${LDAP_BASE_DN}' -w '${LDAP_ADMIN_PASSWORD}' -b 'ou=users,${LDAP_BASE_DN}' '(uid=*)' dn uid cn mail" || true

  echo
  echo "[3] Search groups and members"
  docker exec test-ldap bash -lc \
    "ldapsearch -x -H ldap://localhost:389 -D 'cn=admin,${LDAP_BASE_DN}' -w '${LDAP_ADMIN_PASSWORD}' -b 'ou=groups,${LDAP_BASE_DN}' '(objectClass=groupOfNames)' dn cn member" || true

  echo
}

open_ui_hint() {
  echo "Open in browser: http://localhost:${PHPLDAPADMIN_PORT}"
  echo "Guest mode is on: you are already logged in as cn=admin (no login form)."
}

# ---------------------------
# TUI
# ---------------------------
menu_whiptail() {
  while true; do
    local choice
    choice="$(whiptail \
      --title "${APP_NAME}" \
      --menu "Choose an action" 20 78 10 \
      "1" "Start LDAP + UI" \
      "2" "Stop (down)" \
      "3" "Reset (down -v, nukes data)" \
      "4" "Load sample users and groups (LDIF)" \
      "5" "Run quick tests (ldapwhoami, ldapsearch)" \
      "6" "Status" \
      "7" "Show connection info" \
      "8" "Open LDAP UI in browser" \
      "9" "UI login info" \
      "10" "Exit" \
      3>&1 1>&2 2>&3)" || return 0

    case "${choice}" in
      1) start_stack ;;
      2) stop_stack ;;
      3)
        if whiptail --yesno "This deletes volumes and all LDAP data. Continue?" 10 60; then
          reset_stack
        fi
        ;;
      4) load_sample_data ;;
      5) test_searches ;;
      6) stack_status | sed 's/$/\r/' | whiptail --textbox /dev/stdin 22 90 ;;
      7) info_text | whiptail --textbox /dev/stdin 22 90 ;;
      8) open_ui ;;
      9) open_ui_hint | whiptail --textbox /dev/stdin 12 90 ;;
      10) return 0 ;;
    esac
  done
}

menu_basic() {
  while true; do
    echo
    echo "${APP_NAME}"
    echo "1) Start LDAP + UI"
    echo "2) Stop (down)"
    echo "3) Reset (down -v, nukes data)"
    echo "4) Load sample users and groups (LDIF)"
    echo "5) Run quick tests (ldapwhoami, ldapsearch)"
    echo "6) Status"
    echo "7) Show connection info"
    echo "8) Open LDAP UI in browser"
    echo "9) UI login info" 
  echo "10) Exit"
    echo
    read -r -p "Choice: " choice
    case "${choice}" in
      1) start_stack ;;
      2) stop_stack ;;
      3)
        read -r -p "Delete volumes and all LDAP data? (y/N): " yn
        if [[ "${yn}" == "y" || "${yn}" == "Y" ]]; then
          reset_stack
        fi
        ;;
      4) load_sample_data ;;
      5) test_searches ;;
      6) stack_status ;;
      7) info_text ;;
      8) open_ui ;;
      9) open_ui_hint ;;
      10) return 0 ;;
      *) echo "Invalid choice" ;;
    esac
  done
}

main() {
  if ! have docker; then
    echo "Error: docker not found"
    exit 1
  fi
  if ! compose_cmd >/dev/null 2>&1; then
    echo "Error: docker compose plugin (or docker-compose) not found"
    exit 1
  fi

  ensure_workdir

  if have whiptail; then
    menu_whiptail
  else
    menu_basic
  fi
}

main "$@"
