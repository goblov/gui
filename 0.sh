#!/bin/bash
# ============================================================
#  Script 0 — Базовая установка инструментов
#  Debian 13 netinst
#  Запускать от root:  su -  затем  bash 00_setup_base.sh
# ============================================================

set -e

# ── цвета ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }

# ── проверка: запущен от root ─────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "Запусти скрипт от root:  su -  затем  bash $0"
fi

# ── имя пользователя (тот, кто вызвал su / sudo) ─────────────
TARGET_USER="${SUDO_USER:-$1}"

if [ -z "$TARGET_USER" ]; then
  # попробуем взять первого не-root пользователя из /etc/passwd
  TARGET_USER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)
fi

if [ -z "$TARGET_USER" ]; then
  error "Не удалось определить пользователя. Передай имя аргументом:  bash $0 username"
fi

info "Целевой пользователь: ${YELLOW}${TARGET_USER}${NC}"

# ── обновление списка пакетов ─────────────────────────────────
info "Обновление apt..."
apt-get update -qq

# ── установка пакетов ─────────────────────────────────────────
PACKAGES=(sudo curl git)

for pkg in "${PACKAGES[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    success "$pkg — уже установлен"
  else
    info "Установка $pkg ..."
    apt-get install -y "$pkg"
    success "$pkg — установлен"
  fi
done

# ── добавление пользователя в группу sudo ────────────────────
if id -nG "$TARGET_USER" | grep -qw sudo; then
  success "${TARGET_USER} уже состоит в группе sudo"
else
  info "Добавляем ${TARGET_USER} в группу sudo..."
  usermod -aG sudo "$TARGET_USER"
  success "${TARGET_USER} добавлен в группу sudo"
fi

# ── итог ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Готово!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "  sudo  : $(sudo --version 2>&1 | head -1)"
echo -e "  curl  : $(curl --version | head -1)"
echo -e "  git   : $(git --version)"
echo ""
warn "Перелогинься (или выполни: su - ${TARGET_USER})"
warn "чтобы права sudo вступили в силу."
echo ""
