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
