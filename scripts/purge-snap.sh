#!/bin/bash
set -e

# ==============================================================================
# Snap Purge Utility
#
# Remove por completo o Snapd, todos os pacotes snaps instalados, desativa
# serviços do systemd, remove diretórios residuais e cria uma regra de
# apt pinning (/etc/apt/preferences.d/nosnap.pref) para evitar que o apt
# reinstale o snapd.
# ==============================================================================

DRY_RUN=false
AUTO_CONFIRM=false

show_help() {
    cat << EOF
Snap Purge Utility

Uso: $(basename "$0") [OPÇÕES]

Opções:
  -y, --yes, --assume-yes   Confirma automaticamente a remoção do Snapd e seus arquivos.
  --dry-run                 Exibe os comandos que seriam executados sem alterá-los.
  -h, --help                Exibe esta mensagem de ajuda.
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--assume-yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        echo "Executando: $*"
        "$@"
    fi
}

confirm_purge() {
    if [ "$AUTO_CONFIRM" = true ]; then
        return 0
    fi
    echo "================================================================="
    echo " ATENÇÃO: Este script removerá POR COMPLETO o Snapd e todos os"
    echo " aplicativos instalados via Snap no sistema, além de criar um"
    echo " bloqueio no APT (/etc/apt/preferences.d/nosnap.pref)."
    echo "================================================================="
    read -p "Deseja prosseguir com a remoção completa do Snap? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operação cancelada pelo usuário."
        exit 1
    fi
}

remove_snaps() {
    if command -v snap &>/dev/null; then
        echo "=== Removendo Pacotes Snap Instalados ==="
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Removendo todos os pacotes snap instalados via 'snap remove --purge'..."
        else
            echo "Listando e removendo snaps de aplicativos..."
            while [ "$(snap list 2>/dev/null | wc -l)" -gt 0 ]; do
                app_snaps=$(snap list 2>/dev/null | awk '!/Name|^bare|^core|^snapd/ {print $1}')
                if [ -z "$app_snaps" ]; then
                    break
                fi
                for s in $app_snaps; do
                    echo "Removendo snap: $s..."
                    sudo snap remove --purge "$s" || true
                done
            done

            echo "Removendo snaps base e de sistema (bare, core, snapd)..."
            for s in $(snap list 2>/dev/null | awk '/^bare|^core|^snapd/ {print $1}'); do
                echo "Removendo snap base: $s..."
                sudo snap remove --purge "$s" || true
            done
        fi
    else
        echo "Comando 'snap' não encontrado. Pulando remoção individual de snaps."
    fi
}

stop_services() {
    echo "=== Parando e Desativando Serviços do Snapd ==="
    SERVICES=(
        snapd.service
        snapd.socket
        snapd.seeded.service
        snapd.apparmor.service
    )
    for svc in "${SERVICES[@]}"; do
        run_cmd sudo systemctl stop "$svc" 2>/dev/null || true
        run_cmd sudo systemctl disable "$svc" 2>/dev/null || true
        run_cmd sudo systemctl mask "$svc" 2>/dev/null || true
    done
}

unmount_snaps() {
    echo "=== Desmontando Pontos de Montagem do Snap ==="
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Desmontando todos os pontos /snap e /var/lib/snapd/snap..."
    else
        for mount_point in $(mount | grep snap | awk '{print $3}'); do
            echo "Desmontando: $mount_point..."
            sudo umount -l "$mount_point" || true
        done
    fi
}

purge_packages() {
    echo "=== Expurgando Pacote Snapd via Gerenciador de Pacotes ==="
    if command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
        run_cmd sudo apt remove --purge -y snapd gnome-software-plugin-snap 2>/dev/null || true
        run_cmd sudo apt autoremove --purge -y 2>/dev/null || true
    elif command -v pacman &>/dev/null; then
        run_cmd sudo pacman -Rns --noconfirm snapd 2>/dev/null || true
    fi
}

remove_leftovers() {
    echo "=== Removendo Diretórios e Caches Residuais do Snap ==="
    TARGETS=(
        "$HOME/snap"
        "/snap"
        "/var/snap"
        "/var/lib/snapd"
        "/var/cache/snapd"
        "/usr/lib/snapd"
    )
    for target in "${TARGETS[@]}"; do
        if [ -e "$target" ] || [ -L "$target" ]; then
            run_cmd sudo rm -rf "$target"
        fi
    done
}

apply_apt_pinning() {
    echo "=== Bloqueando Re-instalação do Snapd no APT (Apt Pinning) ==="
    NO_SNAP_PREF="/etc/apt/preferences.d/nosnap.pref"
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Criando $NO_SNAP_PREF com prioridade -10 para o pacote snapd"
    else
        sudo mkdir -p /etc/apt/preferences.d
        sudo bash -c "cat << EOF > $NO_SNAP_PREF
# Impede que o apt reinstale o snapd automaticamente
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF"
        echo "Bloqueio criado com sucesso em $NO_SNAP_PREF."
    fi
}

main() {
    confirm_purge
    remove_snaps
    stop_services
    unmount_snaps
    purge_packages
    remove_leftovers
    apply_apt_pinning

    echo
    echo "================================================================="
    echo " 🎉 O Snapd e todos os seus resíduos foram removidos com sucesso!"
    echo " A re-instalação automática via APT foi bloqueada (/etc/apt/preferences.d/nosnap.pref)."
    echo "================================================================="
}

main "$@"
