#!/usr/bin/env bash

clear
echo -e "\e[40m"  # fundo preto
echo -e "\e[32m"  # texto verde

# Caminhos para imagens
super="$HOME/Projeto/arquivos/imagem_pdv/super"
mix="$HOME/Projeto/arquivos/imagem_pdv/mix"
camino="$HOME/Projeto/arquivos/imagem_pdv/camino"

# Função para gerar IPs
gerar_ips() {
    read -rp "Digite o primeiro IP do intervalo: " ip_inicio
    read -rp "Digite o último IP do intervalo: " ip_fim

    prefixo=$(echo "$ip_inicio" | cut -d. -f1-3)
    inicio=$(echo "$ip_inicio" | cut -d. -f4)
    fim=$(echo "$ip_fim" | cut -d. -f4)

    if [[ "$prefixo" != "$(echo "$ip_fim" | cut -d. -f1-3)" ]]; then
        echo "Os IPs precisam estar no mesmo range /24 (ex: 192.168.1.x)"
        exit 1
    fi

    if (( inicio > fim )); then
        echo "IP inicial maior que o final. Verifique os valores."
        exit 1
    fi

    ips=()
    for ((i=inicio; i<=fim; i++)); do
        ips+=("$prefixo.$i")
    done

    echo -e "\nLista de IPs gerados:"
    for i in "${!ips[@]}"; do
        printf "%2d) %s\n" "$i" "${ips[$i]}"
    done

    read -rp $'\nDeseja excluir algum IP da lista? (s/n): ' resp
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        while true; do
            read -rp "Digite o número do IP que deseja remover (ou ENTER para finalizar): " idx
            [[ -z "$idx" ]] && break
            if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx < ${#ips[@]} )); then
                echo "Removendo: ${ips[$idx]}"
                unset 'ips[idx]'
                ips=("${ips[@]}")  # Reindexa
            else
                echo "Número inválido."
            fi
        done
    fi
}

# Gera senhas com base no IP
gerar_senhas() {
    local ip="$1"
    local ultimo_octeto=$(echo "$ip" | awk -F. '{print $4}')
    local dia=$(date +%d | sed 's/^0*//')
    local mes=$(date +%m | sed 's/^0*//')
    local dia_mes=$((dia * 10 + mes))

    senhas=()
    senhas+=("pdv$dia_mes")  # opcional adicional

    senha_total=$((ultimo_octeto + dia_mes))
    senhas+=("pdv@${senha_total}")

    if (( ${#ultimo_octeto} >= 2 )); then
        ultimos_dois=${ultimo_octeto: -2}
        senha_dois=$((10#$ultimos_dois + dia_mes))
        senhas+=("pdv@${senha_dois}")
    fi

    ultimo_digito=${ultimo_octeto: -1}
    senha_um=$((10#$ultimo_digito + dia_mes))
    senhas+=("pdv@${senha_um}")
}

# Processamento de upload/remover
processar_pdv() {
    local imagem_dir="$1"
    local modo="$2"

    gerar_ips

    echo -e "\nLista final de IPs:"
    printf "%s\n" "${ips[@]}"

    read -rp $'\nDeseja prosseguir com esses IPs? (s/n): ' confirm
    [[ ! "$confirm" =~ ^[Ss]$ ]] && echo "Operação cancelada." && return

    for ip in "${ips[@]}"; do
        if ping -c 1 -W 1 "$ip" &>/dev/null; then
            echo -e "\e[32m$ip PDV ✔On-Line✔\e[m"
            sleep 1

            gerar_senhas "$ip"
            echo "Senhas testadas para $ip: ${senhas[*]}"

            senha_valida=""
            for senha_teste in "${senhas[@]}"; do
                if sshpass -p "$senha_teste" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 suporte@"$ip" "exit" &>/dev/null || \
                   sshpass -p "$senha_teste" sftp -o StrictHostKeyChecking=no -o ConnectTimeout=5 gmpos@"$ip" &>/dev/null <<< "bye"; then
                    senha_valida="$senha_teste"
                    break
                fi
            done

            if [[ -n "$senha_valida" ]]; then
                echo "Senha válida encontrada: $senha_valida"

                if [[ "$modo" == "upload" ]]; then
                    echo "Removendo imagens antigas de $ip..."
                    sshpass -p "$senha_valida" sftp -o StrictHostKeyChecking=no -o CheckHostIP=no gmpos@"$ip" <<EOF
cd /home/gmpos/imagens/
rm *.png
rm imagens.js
bye
EOF

                    echo "Enviando novas imagens para $ip..."
                    sshpass -p "$senha_valida" sftp -o StrictHostKeyChecking=no -o CheckHostIP=no gmpos@"$ip" <<EOF
cd /home/gmpos/imagens/
mput ${imagem_dir}/*.png
mput ${imagem_dir}/imagens.js
bye
EOF

                elif [[ "$modo" == "rm" ]]; then
                    echo "Removendo imagens de $ip..."
                    sshpass -p "$senha_valida" sftp -o StrictHostKeyChecking=no -o CheckHostIP=no gmpos@"$ip" <<EOF
cd /home/gmpos/imagens/
rm *.png
rm imagens.js
bye
EOF
                fi

            else
                echo "Nenhuma senha válida para $ip"
            fi
        else
            echo -e "\e[31m$ip PDV ✘Off-Line✘\e[m"
        fi
    done
}

# Interfaces
super_func() { processar_pdv "$super" "upload"; }
mix_func()   { processar_pdv "$mix" "upload"; }
camino_func(){ processar_pdv "$camino" "upload"; }
exclui_imagem_func() { processar_pdv "" "rm"; }

# Menu
escolha_loja() {
    echo -e "\nSelecione uma loja:"
    echo "1) Super"
    echo "2) Mix"
    echo "3) Camino"
    echo "4) Excluir Imagem"
    echo "0) Sair"
    read -rp "Escolha uma opção: " escolha

    case $escolha in
        1) super_func ;;
        2) mix_func ;;
        3) camino_func ;;
        4) exclui_imagem_func ;;
        0) echo "Saindo..."; exit 0 ;;
        *) echo "Escolha inválida!"; sleep 1 ;;
    esac
}

# Loop principal
while true; do
    escolha_loja
done
