#!/bin/bash
# Entrypoint: prepara configs, levanta xl2tpd y conecta la VPN antes de
# pasar el control al CMD del contenedor.
set -e

: "${VPN_SERVER:?Falta VPN_SERVER en .env}"
: "${VPN_USER:?Falta VPN_USER en .env}"
: "${VPN_PASS:?Falta VPN_PASS en .env}"

echo "==> Renderizando configuración con tus credenciales..."
export VPN_SERVER VPN_USER
envsubst < /config/xl2tpd.conf.template          > /etc/xl2tpd/xl2tpd.conf
envsubst < /config/options.l2tpd.client.template > /etc/ppp/options.l2tpd.client

# CHAP secrets: usuario * contraseña *
echo "\"${VPN_USER}\" * \"${VPN_PASS}\" *"  > /etc/ppp/chap-secrets
echo "\"${VPN_USER}\" * \"${VPN_PASS}\" *" >> /etc/ppp/pap-secrets
chmod 600 /etc/ppp/chap-secrets /etc/ppp/pap-secrets

# /dev/ppp es necesario para pppd; en algunos kernels Docker no lo crea solo.
if [ ! -e /dev/ppp ]; then
    echo "==> Creando /dev/ppp..."
    mknod /dev/ppp c 108 0 || true
fi

# Cargar el módulo ppp_generic si el host lo permite (ignora si falla).
modprobe ppp_generic 2>/dev/null || true

mkdir -p /var/run/xl2tpd

echo "==> Iniciando xl2tpd..."
xl2tpd -D -c /etc/xl2tpd/xl2tpd.conf -s /etc/ppp/chap-secrets &
XL2TPD_PID=$!

# Espera breve para que xl2tpd cree el socket de control.
for i in 1 2 3 4 5; do
    [ -S /var/run/xl2tpd/l2tp-control ] && break
    sleep 1
done

if [ ! -S /var/run/xl2tpd/l2tp-control ]; then
    echo "ERROR: xl2tpd no creó el socket de control. Revisa los logs arriba."
    exit 1
fi

echo "==> Solicitando conexión a 'myvpn'..."
echo "c myvpn" > /var/run/xl2tpd/l2tp-control

# Espera hasta 30s a que aparezca ppp0 con IP asignada.
echo "==> Esperando que el túnel ppp0 levante..."
CONNECTED=0
for i in $(seq 1 30); do
    if ip -4 addr show ppp0 2>/dev/null | grep -q "inet "; then
        CONNECTED=1
        break
    fi
    sleep 1
done

if [ "$CONNECTED" -ne 1 ]; then
    echo ""
    echo "ERROR: la VPN no levantó después de 30s."
    echo "Revisa los mensajes de xl2tpd/pppd más arriba."
    echo "Causas comunes:"
    echo "  - El servidor exige IPsec y no acepta L2TP puro."
    echo "  - Usuario/contraseña incorrectos (revisa .env)."
    echo "  - UDP/1701 bloqueado por tu red."
    exit 1
fi

echo ""
echo "===================================================="
echo " VPN conectada ✓"
ip -4 addr show ppp0 | grep inet | awk '{print "   IP local:  " $2}'
echo " Servidor:   ${VPN_SERVER}"
echo "----------------------------------------------------"
echo " Para hacer SSH a tu destino:    ssh-target"
echo " O un SSH manual:                ssh usuario@host"
echo "===================================================="
echo ""

# Ejecuta lo que pidan en docker run / compose; por defecto: sleep infinity.
exec "$@"
