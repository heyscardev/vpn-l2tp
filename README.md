# VPN L2TP (sin IPsec) + SSH dentro de Docker

Cliente L2TP empaquetado en un contenedor Linux. Levantas el contenedor,
la VPN se conecta sola y haces SSH desde adentro al servicio de la red privada.

## Por qué no se enruta el tráfico del Mac

Docker en macOS corre en una VM Linux; redirigir todo el tráfico del Mac a
través del túnel del contenedor es complicado y frágil. La estrategia
aquí es más simple y robusta: **el cliente SSH también vive en el contenedor**.

## Uso rápido

```bash
cd vpn-l2tp
cp .env.example .env
nano .env                # rellena VPN_*, SSH_*

chmod +x connect.sh entrypoint.sh ssh-target

./connect.sh             # construye, levanta VPN y te mete a un bash
# dentro del contenedor:
ssh-target               # SSH al destino del .env

# para apagar todo:
./connect.sh down
```

Si prefieres saltarte el bash y abrir SSH directo:

```bash
./connect.sh ssh
```

## Comandos manuales (sin connect.sh)

```bash
docker compose up -d --build
docker compose logs -f vpn         # ver el log de conexión
docker compose exec vpn bash       # entrar al contenedor
docker compose exec vpn ssh-target # SSH directo
docker compose down                # apagar
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
