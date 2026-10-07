#!/bin/bash
# Helper: arranca la VPN y te suelta dentro del contenedor con el túnel activo.
# Uso:
#   ./connect.sh           -> entra a un bash dentro del contenedor
#   ./connect.sh ssh       -> conecta y abre SSH al destino del .env
#   ./connect.sh db        -> conecta y abre el gestor de BD en el navegador
#   ./connect.sh down      -> apaga el contenedor
set -e

cd "$(dirname "$0")"

if [ "$1" = "down" ]; then
    docker compose down
    exit 0
fi

if [ ! -f .env ]; then
    echo "Falta .env — copia .env.example a .env y rellena tus datos:"
    echo "    cp .env.example .env && nano .env"
    exit 1
fi

CB_ADMIN_NAME=$(grep -E '^CB_ADMIN_NAME=' .env | cut -d= -f2-)

# Construye (si hace falta) y levanta el contenedor en background
docker compose up -d --build

# Espera a que el entrypoint termine de levantar la VPN.
# Lee logs hasta ver "VPN conectada" o un error.
echo "==> Esperando que el túnel suba..."
for i in $(seq 1 40); do
    if docker compose logs vpn 2>/dev/null | grep -q "VPN conectada"; then
        echo "==> Túnel listo."
        echo "==> Gestor de BD: http://localhost:8978  (usuario: ${CB_ADMIN_NAME:-qa})"
        break
    fi
    if docker compose logs vpn 2>/dev/null | grep -q "ERROR:"; then
        echo "==> Falló la conexión. Logs:"
        docker compose logs vpn
        docker compose down
        exit 1
    fi
    sleep 1
done

if [ "$1" = "db" ]; then
    echo "==> Esperando que CloudBeaver arranque..."
    for i in $(seq 1 60); do
        curl -sf -o /dev/null http://localhost:8978/ && break
        sleep 2
    done
    open http://localhost:8978
elif [ "$1" = "ssh" ]; then
    docker compose exec vpn ssh-target
else
    docker compose exec vpn bash
fi
