#!/usr/bin/env bash

clear
echo -e "\e[40m"
echo -e "\e[32m"

# ==========================
# Arquivos de marketing
# ==========================
super=( "$HOME/Projeto/arquivos/imagem_pdv/super/"*.png "$HOME/Projeto/arquivos/imagem_pdv/super/imagens.js" )
mix=( "$HOME/Projeto/arquivos/imagem_pdv/mix/"*.png "$HOME/Projeto/arquivos/imagem_pdv/mix/imagens.js" )
camino=( "$HOME/Projeto/arquivos/imagem_pdv/camino/"*.png "$HOME/Projeto/arquivos/imagem_pdv/camino/imagens.js" )
diretorio="/mpos/maxipos/pos/l0*/t0*/imagens"

# ==========================
# Menu principal
# ==========================
escolha_loja() {
    clear
    date
    w
    echo -e "\e[32m"
    echo "☢================Atualizar Imagens de Marketing PDV===================☢"
    echo "|[0] Voltar                                                           |"
    echo "|[1] Mix                                                              |"
    echo "|[2] Super                                                            |"
    echo "|[3] Camino                                                           |"
    echo "|[4] Enviar por Range de IPs                                          |"
    echo "☢=====================================================================☢"
    read -p "Qual tipo de loja? " opc
    echo -e "\e[m"
    case $opc in
        1) enviar_mix ;;
        2) enviar_super ;;
        3) enviar_camino ;;
        4) enviar_range ;;
        0) exit 0 ;;
        *) echo "Escolha inválida! ¯\\_(ツ)_/¯"; sleep 1 ;;
    esac
}

# ==========================
# Funções de envio por tipo
# ==========================
enviar_super() 
{
    ips=(192.168.47 192.168.44 192.168.50 192.168.51 192.168.187 192.168.199)
    enviar_arquivos ips[@] super[@]
}

enviar_mix() 
{
    ips=(192.168.42 192.168.45 192.168.119 192.168.158 192.168.155 192.168.159 192.168.228 172.23.3 172.23.7 172.23.27)
    enviar_arquivos ips[@] mix[@]
}

enviar_camino() 
{
    ips=(172.23.4 172.23.46)
    enviar_arquivos ips[@] camino[@]
}

# ==========================
# Função genérica de envio
# ==========================
enviar_arquivos() 
{
    local ip_bases_name=$1
    local arquivos_name=$2

    local ip_bases=( "${!ip_bases_name}" )
    local arquivos=( "${!arquivos_name}" )

    for ip_base in "${ip_bases[@]}"; do
        for i in {101..160}; do
            ip="$ip_base.$i"
            echo -e "\n🔄 Enviando para $ip..."
            ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip" &>/dev/null

            #coleta=$(sshpass -p 1 ssh -o ConnectTimeout=3 -oStrictHostKeyChecking=no root@"$ip" \
            #    "find /mpos/maxipos/pos -type d -path '/mpos/maxipos/pos/l0*/t0*/imagens' 2>/dev/null" | head -n 1)

            [[ -z "$coleta" ]] && echo "⚠ Diretório de destino não encontrado em $ip. Pulando..." && continue

            for arquivo in "${arquivos[@]}"; do
                [[ -e "$arquivo" ]] || continue
                sshpass -p 1 scp -Crp -oStrictHostKeyChecking=no -oCheckHostIP=no "$arquivo" root@"$ip":"$diretorio"/
                [[ $? -eq 0 ]] && echo "✔ Arquivo $arquivo enviado para $ip." || echo "✗ Erro ao enviar $arquivo para $ip."
            done
            sleep 1
        done
    done
    echo -e "\n✅ Transferência finalizada."
}


# ==========================
# Função de envio por range
# ==========================
enviar_range() 
{
    read -p "Digite o IP inicial completo (ex: 192.168.47.101): " ip_inicio
    read -p "Digite o IP final completo (ex: 192.168.47.160): " ip_fim
    read -p "Digite IPs para excluir separados por espaço (ou ENTER para nenhum): " excluidos_input

    # Converte a lista de IPs excluídos em array
    read -ra excluidos <<< "$excluidos_input"

    # Extrai base e octetos finais
    IFS='.' read -r a b c d_ini <<< "$ip_inicio"
    IFS='.' read -r _ _ _ d_fim <<< "$ip_fim"
    ip_base="$a.$b.$c"

    # Escolha de arquivos
    arquivos_choice() {
        echo "Escolha arquivos para enviar:"
        echo "[1] Mix"
        echo "[2] Super"
        echo "[3] Camino"
        read -p "Opção: " opc
        case $opc in
            1) arquivos=("${mix[@]}") ;;
            2) arquivos=("${super[@]}") ;;
            3) arquivos=("${camino[@]}") ;;
            *) echo "Opção inválida!"; return 1 ;;
        esac
    }

    arquivos_choice || return

    for i in $(seq $d_ini $d_fim); do
        ip="$ip_base.$i"

        # Pula IPs que estão na lista de excluídos
        skip=false
        for ex in "${excluidos[@]}"; do
            [[ "$ip" == "$ex" ]] && skip=true && break
        done
        $skip && continue

        echo -e "\n🔄 Enviando para $ip..."
        ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip" &>/dev/null

        #coleta=$(sshpass -p 1 ssh -o ConnectTimeout=3 -oStrictHostKeyChecking=no root@"$ip" \
        #    "find /mpos/maxipos/pos -type d -path '/mpos/maxipos/pos/l0*/t0*/imagens' 2>/dev/null" | head -n 1)

        [[ -z "$coleta" ]] && echo "⚠ Diretório não encontrado em $ip. Pulando..." && continue

        # Envia arquivos
        for arquivo in "${arquivos[@]}"; do
            [[ -e "$arquivo" ]] || continue
            sshpass -p 1 scp -Crp -oStrictHostKeyChecking=no -oCheckHostIP=no "$arquivo" root@"$ip":"$diretorio"/
            [[ $? -eq 0 ]] && echo "✔ Arquivo $arquivo enviado para $ip." || echo "✗ Erro ao enviar $arquivo para $ip."
        done
        sleep 1
    done
    echo -e "\n✅ Transferência finalizada."
}

# ==========================
# Loop principal
# ==========================
while true; do
    escolha_loja
done
