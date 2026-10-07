# VPN L2TP (sin IPsec) + SSH dentro de Docker

Cliente L2TP empaquetado en un contenedor Linux. Levantas el contenedor,
la VPN se conecta sola y haces SSH desde adentro al servicio de la red privada.

## Por qué no se enruta el tráfico del Mac

Docker en macOS corre en una VM Linux; redirigir todo el tráfico del Mac a
través del túnel del contenedor es complicado y frágil. La estrategia
aquí es más simple y robusta: **el cliente SSH también vive en el contenedor**.

## Uso rápido

```bash
cp .env.example .env
# edita .env con tus credenciales (ver sección Configuración)

docker compose build     # solo la primera vez o al cambiar configs
docker compose up        # levanta la VPN
```

Cuando veas esto, la VPN está activa:

```
====================================================
 VPN conectada ✓
   IP local:  192.168.x.x
 Servidor:   xxx.xxx.xxx.xxx
----------------------------------------------------
 Para hacer SSH a tu destino:    ssh-target
====================================================
```

Desde otra terminal, con la VPN corriendo:

```bash
docker exec -it l2tp-vpn ssh-target          # SSH interactivo
docker exec -it l2tp-vpn ssh-target "comando" # ejecutar un comando remoto
```

Para apagar:

```bash
docker compose down
```

## Configuración (.env)

```env
VPN_SERVER=vpn.ejemplo.com   # IP o dominio del servidor L2TP
VPN_USER=tu_usuario
VPN_PASS=tu_contraseña       # si tiene $ escríbelo como $$  (ej: pa$$word → pa$word)

SSH_HOST=192.168.10.x        # IP interna accesible desde la VPN
SSH_PORT=22
SSH_USER=tu_usuario_ssh
SSH_PASS=tu_contraseña_ssh   # deja vacío si usas llave SSH
```

## Usar tus llaves SSH del Mac

En `docker-compose.yml`, descomenta el bloque `volumes:` para montar
`~/.ssh` del host en el contenedor (solo lectura). Deja `SSH_PASS` vacío
en `.env` y tu llave se usará automáticamente.

## Gestor de base de datos (interfaz gráfica)

La VPN solo existe dentro del contenedor, así que el gestor también corre en
Docker: **CloudBeaver** (equivalente web de DBeaver) en el servicio `dbgui`,
que comparte la red del contenedor `vpn`. No hay que instalar nada en el Mac.

```bash
./connect.sh db     # levanta VPN + gestor y abre http://localhost:8978
```

Entra con `CB_ADMIN_NAME` / `CB_ADMIN_PASSWORD` del `.env`. La conexión a la
BD ya aparece creada (se genera desde el `.env` en cada arranque), de solo
lectura por defecto (`DB_READ_ONLY=1`) y marcada como producción.

Configura en `.env`:

```env
DB_HOST=10.0.0.20       # IP/host de la BD
DB_PORT=5432            # puerto real de la BD
DB_LOCAL_PORT=15432     # puerto en 127.0.0.1 del Mac
DB_VIA_SSH=0
DB_TYPE=postgres        # postgres | mysql | mariadb | sqlserver | oracle
DB_NAME=mi_base
DB_USER=usuario_bd
DB_PASS=contraseña_bd
DB_READ_ONLY=1

CB_ADMIN_NAME=qa
CB_ADMIN_PASSWORD=Cambiame123   # mín. 8, mayúsculas/minúsculas y 1 número
```

- `DB_VIA_SSH=0`: la BD es alcanzable directo desde la VPN (`socat`).
- `DB_VIA_SSH=1`: la BD solo es accesible desde `SSH_HOST`; se abre un túnel
  SSH con las mismas credenciales de `ssh-target`. Si la BD escucha en el
  propio servidor SSH usa `DB_HOST=localhost` (no `127.0.0.1`: si la BD escucha solo en IPv6 `::1` fallaría).

El túnel se reconecta solo si se cae. Las conexiones creadas a mano en la UI
se pierden al reiniciar: gestiona la conexión desde `.env`.

### Descargar un backup de la BD

CloudBeaver (versión Community) no hace backups completos; solo exporta
tablas o resultados de consultas (clic derecho → **Export Data** → CSV, SQL,
JSON o XLSX). Para un backup completo usa `pg_dump` desde el contenedor:

```bash
./connect.sh backup                   # backup completo en ./backups/
./connect.sh backup --schema-only     # solo estructura
./connect.sh backup -t orders         # solo una tabla
```

Genera `backups/<DB_NAME>_<fecha>.dump` (formato custom, comprimido). Para
restaurarlo en una BD local:

```bash
pg_restore --no-owner -d postgres://usuario@localhost:5432/mi_base backups/arpec_XXXX.dump
```

El cliente es PostgreSQL 17 (`PG_CLIENT_VERSION` en el `Dockerfile`); debe
ser igual o más nuevo que la versión del servidor. Solo funciona con
`DB_TYPE=postgres`.

### Usar un cliente de escritorio (opcional)

La BD también queda en `127.0.0.1:DB_LOCAL_PORT` del Mac, así que puedes
conectarte con DBeaver / TablePlus / DataGrip si lo prefieres.

## Si la VPN no levanta

El `entrypoint.sh` espera 30s a que aparezca `ppp0`. Si falla:

- Verifica usuario/contraseña en `.env`.
- Comprueba que el servidor realmente acepte L2TP **sin** IPsec.
  Lo más común es que exija IPsec — en ese caso esto no funcionará.
- UDP/1701 debe estar abierto entre tu Mac y el servidor.
- Mira los logs: `docker compose logs vpn`.

## Seguridad

- El contenedor corre `privileged: true` porque `xl2tpd` necesita
  capacidades de red y `/dev/ppp`. Es aceptable para uso personal.
- L2TP sin IPsec viaja sin cifrar a nivel de túnel. Asegúrate de que
  el SSH (que ya cifra) sea suficiente para tu caso de uso.
- Con `DB_VIA_SSH=0` el tráfico de la BD viaja por ese túnel sin cifrar;
  usa SSL en la conexión de la BD o `DB_VIA_SSH=1` si es posible.
- Los puertos se publican solo en `127.0.0.1`, no en tu red local.
- Para prod, usa un usuario de BD de solo lectura cuando no necesites escribir.
