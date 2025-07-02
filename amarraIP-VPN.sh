#!/usr/bin/env bash
clear

sudo tailscale up

# Exibe interfaces com cores
ip -c addr

echo -e "\e[33m__________________________________________________________________"
echo -e "|                         VPN Tailscale                          |"
echo -e "|________________________________________________________________|"
read -p "Digite o IP da interface que você quer amarrar à VPN: " endereco
read -p "Digite o IP/CIDR para liberar a rota (ex: 100.64.0.0/10): " rota
read -p "Digite o nome da interface (ex: eth0): " interface
echo -e "________________________________________________________________\e[m"

# Verifica se a tabela já existe para evitar duplicações
if ! grep -q "200 tailscale" /etc/iproute2/rt_tables; then
    echo "200 tailscale" | sudo tee -a /etc/iproute2/rt_tables
fi

# Adiciona a rota na tabela personalizada
sudo ip route add "$rota" dev tailscale0 table tailscale 2>/dev/null || \
    echo -e "\e[31m[Rota já existe ou falhou]\e[m"

# Cria regra de roteamento com base no IP da interface
sudo ip rule add from "$endereco" table tailscale 2>/dev/null || \
    echo -e "\e[31m[Regra já existe ou falhou]\e[m"

# Opção de bloquear Tailscale para outras interfaces
read -p "Deseja bloquear a VPN para outras interfaces temporariamente [s/n]? " escolha
case "$escolha" in
    s|S)
        sudo iptables -A OUTPUT -o ! "$interface" -p udp --dport 41641 -j DROP
        echo -e "\e[32mVPN bloqueada para interfaces diferentes de $interface\e[m"
        ;;
    n|N)
        echo -e "\e[33mNenhum bloqueio de interface foi aplicado\e[m"
        ;;
    *)
        echo -e "\e[31mOpção inválida\e[m"
        ;;
esac

echo -e "\e[32mConfiguração concluída.\e[m"
