#!/bin/bash

LOGFILE="/tmp/backdoor_alert.log"
ALERT=false

# Limpa o log anterior
> "$LOGFILE"

check() {
    echo "[*] $1" >> "$LOGFILE"
    eval "$2" >> "$LOGFILE"
    if [ $? -eq 0 ]; then
        ALERT=true
    fi
}

# 1. Conexões de rede suspeitas
check "Conexões de rede suspeitas:" \
"ss -tulpan | grep -vE '127.0.0.1|::1|0.0.0.0:22|LISTEN' | grep -v 'chrome\|firefox'"

# 2. Arquivos com nomes incomuns
check "Arquivos suspeitos com extensões estranhas:" \
"find / -type f -regextype posix-extended -regex '.*\.[a-zA-Z]{8,}$' 2>/dev/null | head -n 10"

# 3. Processos de caminhos suspeitos
check "Processos em diretórios não convencionais:" \
"ps aux | awk '\$11 !~ \"^/usr/bin|^/bin|^/sbin\"' | grep -vE '^\[' | head -n 10"

# 4. Executáveis com setuid/setgid
check "Executáveis com setuid/setgid:" \
"find / -perm /6000 -type f 2>/dev/null | head -n 10"

# 5. Scripts em /tmp ou /dev/shm
check "Scripts suspeitos em /tmp ou /dev/shm:" \
"find /tmp /dev/shm -type f -exec file {} \; 2>/dev/null | grep -i 'script' | head -n 10"

# 6. Mudanças recentes em arquivos sensíveis
check "Arquivos modificados recentemente:" \
"find /etc /bin /usr/bin /usr/sbin -type f -mtime -1 2>/dev/null | head -n 10"

# 7. chkrootkit (opcional)
if command -v chkrootkit >/dev/null 2>&1; then
    check "chkrootkit detectou algo?" \
    "chkrootkit | grep -v 'not found' | grep -v 'not infected'"
fi

# NOTIFICAÇÃO
if [ "$ALERT" = true ]; then
    echo "[!!!] POSSÍVEL BACKDOOR DETECTADO! Veja o relatório em: $LOGFILE"
    # opcional: notificar por e-mail, telegram, notify-send, etc
else
    rm -f "$LOGFILE"  # limpa se nada suspeito for encontrado
fi
