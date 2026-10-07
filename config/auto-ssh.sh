# Se carga desde /root/.bashrc: al abrir una shell interactiva como root
# salta directo al destino SSH si la VPN está arriba.
# Para obtener una shell normal en el contenedor:  AUTO_SSH=0
if [[ $- == *i* ]] && [ "${AUTO_SSH:-1}" = "1" ] && [ -z "$AUTO_SSH_ACTIVE" ]; then
    export AUTO_SSH_ACTIVE=1
    if ip -4 addr show ppp0 2>/dev/null | grep -q "inet "; then
        echo "==> Conectando a ${SSH_USER}@${SSH_HOST}... (AUTO_SSH=0 para shell local)"
        # exec: al salir del SSH se cierra también la sesión del contenedor.
        exec ssh-target
    else
        echo "==> VPN no activa (ppp0 sin IP); quedas en shell local."
    fi
fi
