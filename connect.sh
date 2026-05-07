#!/bin/bash
# Helper: arranca la VPN y te suelta dentro del contenedor con el túnel activo.
# Uso:
#   ./connect.sh           -> entra a un bash dentro del contenedor
#   ./connect.sh ssh       -> conecta y abre SSH al destino del .env
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

# Construye (si hace falta) y levanta el contenedor en background
docker compose up -d --build

# Espera a que el entrypoint termine de levantar la VPN.
# Lee logs hasta ver "VPN conectada" o un error.
echo "==> Esperando que el túnel suba..."
for i in $(seq 1 40); do
    if docker compose logs vpn 2>/dev/null | grep -q "VPN conectada"; then
        echo "==> Túnel listo."
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

if [ "$1" = "ssh" ]; then
    docker compose exec vpn ssh-target
else
    docker compose exec vpn bash
fi
