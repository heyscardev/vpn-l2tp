#!/bin/bash
# Arranque de CloudBeaver: genera la conexión a la BD a partir del .env y
# lanza el servidor. La conexión se regenera en cada arranque, así que se
# gestiona desde .env (las conexiones creadas a mano en la UI se pierden).
set -e

WORKSPACE=/opt/cloudbeaver/workspace
DS_DIR="$WORKSPACE/GlobalConfiguration/.dbeaver"

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

if [ -n "$DB_HOST" ]; then
    # dbgui comparte la red del contenedor vpn: la BD está en el puerto de db-forward.
    HOST=127.0.0.1
    PORT="${DB_LOCAL_PORT:-15432}"
    DB_NAME="${DB_NAME:-}"

    case "${DB_TYPE:-postgres}" in
        postgres)  PROVIDER=postgresql; DRIVER=postgres-jdbc; URL="jdbc:postgresql://${HOST}:${PORT}/${DB_NAME}" ;;
        mysql)     PROVIDER=mysql;      DRIVER=mysql8;        URL="jdbc:mysql://${HOST}:${PORT}/${DB_NAME}" ;;
        mariadb)   PROVIDER=mysql;      DRIVER=mariaDB;       URL="jdbc:mariadb://${HOST}:${PORT}/${DB_NAME}" ;;
        sqlserver) PROVIDER=sqlserver;  DRIVER=microsoft;     URL="jdbc:sqlserver://${HOST}:${PORT};databaseName=${DB_NAME};trustServerCertificate=true" ;;
        oracle)    PROVIDER=oracle;     DRIVER=oracle_thin;   URL="jdbc:oracle:thin:@//${HOST}:${PORT}/${DB_NAME}" ;;
        *) echo "DB_TYPE no soportado: ${DB_TYPE} (postgres|mysql|mariadb|sqlserver|oracle)"; exit 1 ;;
    esac

    if [ "${DB_READ_ONLY:-1}" = "1" ]; then READ_ONLY=true; else READ_ONLY=false; fi

    mkdir -p "$DS_DIR" "$WORKSPACE/.metadata"
    cat > "$DS_DIR/data-sources.json" <<EOF
{
  "folders": {},
  "connections": {
    "vpn-db": {
      "provider": "${PROVIDER}",
      "driver": "${DRIVER}",
      "name": "$(json_escape "${DB_CONNECTION_NAME:-Producción}")",
      "save-password": true,
      "read-only": ${READ_ONLY},
      "configuration": {
        "host": "${HOST}",
        "port": "${PORT}",
        "database": "$(json_escape "$DB_NAME")",
        "url": "$(json_escape "$URL")",
        "type": "prod",
        "auth-model": "native",
        "user": "$(json_escape "${DB_USER:-}")",
        "password": "$(json_escape "${DB_PASS:-}")"
      }
    }
  }
}
EOF
    echo "==> Conexión '${DB_CONNECTION_NAME:-Producción}' (${DB_TYPE:-postgres}, read-only=${READ_ONLY}) configurada."
fi

exec ./launch-product.sh "$@"
