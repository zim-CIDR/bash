#!/usr/bin/env bash
menuPrincipal()
{
    consultarDominio()
    {
        clear
        # Cores neon
        CYAN="\e[96m"
        MAGENTA="\e[95m"
        GREEN="\e[92m"
        RED="\e[91m"
        YELLOW="\e[93m"
        RESET="\e[0m"

        banner()
        {
            echo -e "${MAGENTA}"
            echo "───────────────────────────────────────────"
            echo "   🧠 CYBERPUNK RDAP LOOKUP by Will"
            echo "───────────────────────────────────────────"
            echo -e "${RESET}"
        }

        check_install()
        {
            local cmd="$1"
            local pkg="$2"
            if ! command -v "$cmd" &>/dev/null; then
                echo -e "${YELLOW}⚡ $cmd não encontrado. Tentando instalar...${RESET}"
                if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y "$pkg"
                elif command -v yum &>/dev/null; then
                sudo yum install -y "$pkg"
                elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm "$pkg"
                else
                echo -e "${RED}❌ Não foi possível instalar $pkg automaticamente. Instale manualmente.${RESET}"
                exit 1
                fi
            fi
        }

        # Verifica dependências
        check_install curl curl
        check_install jq jq
        # Verifica se o 'ping' está disponível (em alguns sistemas, o pacote é iputils-ping)
        if ! command -v ping &>/dev/null; then
            echo -e "${YELLOW}⚡ ping não encontrado. Tentando instalar iputils-ping...${RESET}"
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y iputils-ping
            elif command -v yum &>/dev/null; then
                sudo yum install -y iputils-ping
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sy --noconfirm iputils-ping
            else
                echo -e "${RED}❌ Não foi possível instalar ping. Instale manualmente o 'ping' ou 'iputils-ping'.${RESET}"
                exit 1
            fi
        fi

        # Nova função para verificar status e obter IP
        check_online_and_get_ip()
        {
            local dominio="$1"
            local ip_resolvido

            # Tenta resolver o IP primeiro
            ip_resolvido=$(dig +short "$dominio" | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' | head -n 1)

            if [[ -z "$ip_resolvido" ]]; then
                echo -e "${RED}🌐 Endereço:${RESET} ${RED}OFFLINE (Sem resolução de IP)${RESET}"
                echo -e "${CYAN}📡 IP:${RESET} ${RED}N/A${RESET}"
                return 1 # Endereço não resolveu
            fi

            echo -e "${CYAN}📡 IP:${RESET} $ip_resolvido"

            # Tenta dar 1 ping para verificar se está online
            if ping -c 1 -W 1 "$ip_resolvido" &>/dev/null; then
                echo -e "${GREEN}🌐 Endereço:${RESET} ${GREEN}ONLINE${RESET}"
                return 0 # Endereço online
            else
                # O IP resolveu, mas não respondeu ao ping
                echo -e "${YELLOW}🌐 Endereço:${RESET} ${YELLOW}OFFLINE (IP não responde a ping)${RESET}"
                return 1 # Endereço offline
            fi
        }


        consulta_rdap()
        {
            local dominio="$1"

            if [[ -z "$dominio" ]]; then
                echo -e "${RED}⚠️  Digite um domínio para consultar.${RESET}"
                return 1
            fi

            # 1. VERIFICA STATUS E MOSTRA IP
            echo -e "\n${YELLOW}⚡ Verificando status e resolvendo IP...${RESET}"
            # Executa a nova função, mas ignora o código de retorno para garantir que o RDAP seja consultado,
            # mesmo que esteja offline (o RDAP é útil de qualquer forma).
            check_online_and_get_ip "$dominio"

            # 2. CONSULTA RDAP
            echo -e "\n${YELLOW}⏳ Consultando RDAP / ICANN para: ${CYAN}${dominio}${RESET}"
            local tld="${dominio##*.}"

            if [[ "$tld" == "br" ]]; then
                local url="https://rdap.registro.br/domain/${dominio}"
                local data
                data=$(curl -s "$url")

                if [[ -z "$data" || "$(echo "$data" | jq -r '.errorCode // empty')" != "" ]]; then
                echo -e "${RED}❌ Domínio não encontrado no Registro.br${RESET}"
                return 1
                fi

                local registrar owner email criacao atualizacao expiracao
                registrar=$(echo "$data" | jq -r '.registrar.name // "Registro.br"')
                criacao=$(echo "$data" | jq -r '.events[]? | select(.eventAction=="registration") | .eventDate' 2>/dev/null)
                atualizacao=$(echo "$data" | jq -r '.events[]? | select(.eventAction=="last changed") | .eventDate' 2>/dev/null)
                expiracao=$(echo "$data" | jq -r '.events[]? | select(.eventAction=="expiration") | .eventDate' 2>/dev/null)
                owner=$(echo "$data" | jq -r '.entities[]?.vcardArray[1][]? | select(.[0]=="fn") | .[3]' | head -n1)
                email=$(echo "$data" | jq -r '.entities[]?.vcardArray[1][]? | select(.[0]=="email") | .[3]' | head -n1)

                echo -e "\n${MAGENTA}⚡ Dados RDAP (.BR)${RESET}"
                echo "───────────────────────────────────────────"
                echo -e "${CYAN}🌐 Domínio:${RESET} $dominio"
                echo -e "${CYAN}👤 Titular:${RESET} ${owner:-(oculto)}"
                echo -e "${CYAN}📧 E-mail:${RESET} ${email:-(não disponível)}"
                echo -e "${CYAN}🏢 Registrar:${RESET} $registrar"
                echo -e "${CYAN}📅 Criado em:${RESET} ${criacao:-—}"
                echo -e "${CYAN}♻️ Atualizado em:${RESET} ${atualizacao:-—}"
                echo -e "${CYAN}⏳ Expira em:${RESET} ${expiracao:-—}"
                echo -e "${CYAN}📡 Nameservers:${RESET}"
                echo "$data" | jq -r '.nameservers[]?.ldhName' | sed "s/^/   - /"
                return 0
            fi

            # --- Outros TLDs ---
            local bootstrap="https://data.iana.org/rdap/dns.json"
            local rdap_server
            rdap_server=$(curl -s "$bootstrap" | jq -r ".services[] | select(.[0][] | contains(\".${tld}\")) | .[1][0]" | head -n1)

            if [[ -z "$rdap_server" || "$rdap_server" == "null" ]]; then
                echo -e "${RED}❌ Nenhum servidor RDAP encontrado para .${tld}${RESET}"
                return 1
            fi

            local data
            data=$(curl -s "${rdap_server}/domain/${dominio}")

            if [[ -z "$data" || "$(echo "$data" | jq -r '.errorCode // empty')" != "" ]]; then
                echo -e "${RED}❌ Domínio não encontrado no servidor RDAP${RESET}"
                return 1
            fi

            local registrar owner email criacao atualizacao expiracao
            registrar=$(echo "$data" | jq -r '.registrar.name // "Não informado"')
            criacao=$(echo "$data" | jq -r '.events[]? | select(.eventAction=="registration") | .eventDate' 2>/dev/null)
            atualizacao=$(echo "$data" | jq -r '.events[]? | select(.eventAction=="last changed") | .eventDate' 2>/dev/null)
            expiracao=$(echo "$data" | jq -r '.events[]? | select(.eventAction=="expiration") | .eventDate' 2>/dev/null)
            owner=$(echo "$data" | jq -r '.entities[]? | select(.roles[]? | test("registrant|administrative|technical";"i")) | .vcardArray[1][]? | select(.[0]=="fn") | .[3]' | head -n1)
            email=$(echo "$data" | jq -r '.entities[]? | select(.roles[]? | test("registrant|administrative|technical";"i")) | .vcardArray[1][]? | select(.[0]=="email") | .[3]' | head -n1)

            if [[ -z "$email" || "$email" == "null" ]]; then
                email=$(echo "$data" | jq -r '.entities[]? | select(.roles[]? | test("abuse";"i")) | .vcardArray[1][]? | select(.[0]=="email") | .[3]' | head -n1)
            fi

            echo -e "\n${MAGENTA}⚡ Dados RDAP (TLD Internacional)${RESET}"
            echo "───────────────────────────────────────────"
            echo -e "${CYAN}🌐 Domínio:${RESET} $dominio"
            echo -e "${CYAN}👤 Registrante:${RESET} ${owner:-(protegido)}"
            echo -e "${CYAN}📧 E-mail:${RESET} ${email:-(oculto)}"
            echo -e "${CYAN}🏢 Registrar:${RESET} $registrar"
            echo -e "${CYAN}📅 Criado em:${RESET} ${criacao:-—}"
            echo -e "${CYAN}♻️ Atualizado em:${RESET} ${atualizacao:-—}"
            echo -e "${CYAN}⏳ Expira em:${RESET} ${expiracao:-—}"
            echo -e "${CYAN}📡 Nameservers:${RESET}"
            echo "$data" | jq -r '.nameservers[]?.ldhName' | sed "s/^/   - /"

            return 0
        }

        # Loop principal
        while true; do
            clear
            banner
            read -p "Digite o domínio: " dominio
            if ! consulta_rdap "$dominio"; then
                echo -e "\n${RED}❌ Ocorreu um erro na consulta RDAP!${RESET}"
                read -p "Pressione Enter para consultar outro domínio..."
                continue
            fi
            echo -e "\n${GREEN}✅ Consulta concluída!${RESET}"
            echo
            echo "[0] VOLTAR"
            echo "[1] NOVA CONSULTA"
            echo "[2] SAIR"

            read -p "Escolha: " escolha

            case $escolha in
                0) return ;;
                1) continue ;;
                2) echo -e "\e[31msaindo...\e[m";sleep 2; clear; exit 0 ;;
                *) echo -e  "\e[31m Opção inválida\e[m"; sleep 2 ;;
            esac

        done

    }

    varrerEndPoint()
    {
        clear
        # CORES
        RED="\e[31m"
        GREEN="\e[32m"
        YELLOW="\e[33m"
        BLUE="\e[34m"
        CYAN="\e[36m"
        MAGENTA="\e[35m"
        RESET="\e[0m"

        # BANNER
        echo -e "${MAGENTA}"
        echo "███████╗██████╗ ███████╗ █████╗ ██╗  ██╗"
        echo "██╔════╝██╔══██╗██╔════╝██╔══██╗██║ ██╔╝"
        echo "█████╗  ██████╔╝█████╗  ███████║█████╔╝ "
        echo "██╔══╝  ██╔══██╗██╔══╝  ██╔══██║██╔═██╗ "
        echo "██║     ██║  ██║███████╗██║  ██║██║  ██╗"
        echo "╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝"
        echo -e "${RESET}"

        echo -e "${CYAN}Freak Endpoint Recon Scanner${RESET}"
        echo

        # MENU STATUS CODE
        echo -e "${YELLOW}Selecione os Status Code que deseja${RESET}"
        echo -e "${CYAN}"
        echo -e "\e[31m0) SAIR\e[m"
        echo    "1) 200  - OK (endpoint acessível)"
        echo    "2) 301  - Redirect permanente"
        echo    "3) 302  - Redirect temporário"
        echo    "4) 401  - Unauthorized"
        echo    "5) 403  - Forbidden"
        echo    "6) 405  - Method Not Allowed"
        echo    "7) 500  - Internal Server Error"
        echo -e "8) VOLTAR"
        echo -e "${RESET}"
        read -p "Digite os números separados por espaço (ex: 1 4 5): " OPTIONS

        TARGET_CODES=()

        for i in $OPTIONS
        do
            case $i in
                0) echo -e "\e[31mSAINDO...\e[m"; sleep 1; clear; exit 0 ;;
                1) TARGET_CODES+=("200") ;;
                2) TARGET_CODES+=("301") ;;
                3) TARGET_CODES+=("302") ;;
                4) TARGET_CODES+=("401") ;;
                5) TARGET_CODES+=("403") ;;
                6) TARGET_CODES+=("405") ;;
                7) TARGET_CODES+=("500") ;;
                8) return ;;
                *) echo -e "\e[31mOPÇÃO INVÁLIDA\e[m"; sleep 2 ;;
            esac
        done

        echo
        read -p "Digite a URL: " URL

        URL1="https://raw.githubusercontent.com/z5jt/API-documentation-Wordlist/main/API-documentation-Wordlist/api-documentation-endpoint.txt"
        URL2="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/Logins.fuzz.txt"
        URL3="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/api/api-endpoints-res.txt"
        URL4="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/api/api-endpoints.txt"

        echo
        echo -e "${CYAN}[+] Inicializando scanner Freak...${RESET}"

        while read -r endpoint
        do

        [[ -z "$endpoint" ]] && continue

        TEST_URL="$URL/$endpoint"

        echo -ne "${CYAN}[SCAN] -> ${YELLOW}$TEST_URL${RESET}        \r"

        CODE=$(curl -o /dev/null -s -w "%{http_code}" "$TEST_URL")

        for target in "${TARGET_CODES[@]}"
        do
        if [[ "$CODE" == "$target" ]]
        then
        echo -e "${GREEN}[FOUND] $TEST_URL -> HTTP $CODE${RESET}"
        fi
        done

        done < <(
        {
        curl -s "$URL1"
        curl -s "$URL2"
        curl -s "$URL3"
        curl -s "$URL4"
        } | sed '/^$/d' | sort -u
        )

        echo
        echo -e "${MAGENTA}[+] Scan finalizado.${RESET}"

        echo
        echo "[0] VOLTAR"
        echo "[1] NOVO SCAN"
        echo "[2] SAIR"

        read -p "Escolha: " opc

        case $opc in
        0) return ;;
        1) varrerEndPoint ;;
        2) exit 0 ;;
        *) echo "OPÇÃO INVALIDA"; sleep 2 ;;
        esac

    }

    clear

    # CORES
    MAGENTA="\e[35m"
    CYAN="\e[36m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    RESET="\e[0m"

    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════╗"
    echo "║           FREAK SECURITY TOOL        ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${CYAN}>> Módulos disponíveis${RESET}"
    echo

    echo -e "${GREEN}[01]${RESET} ${YELLOW}Consultar Domínio (RDAP)${RESET}"
    echo -e "${GREEN}[02]${RESET} ${YELLOW}Scanner de Endpoint${RESET}"
    echo -e "${GREEN}[00]${RESET} ${YELLOW}Encerrar sistema${RESET}"
    echo
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -p "$USER@freak:~#" resp

    case $resp in
        00|0) echo -e "\e[31mSAINDO...\e[m"; sleep 1; clear; exit 0 ;;
        1|01) consultarDominio ;;
        2|02) varrerEndPoint ;;
        *) echo -e "\e[31mOPÇÃO INVÁLIDA\e[m"; sleep 2 ;;
    esac
}

while true
do
    menuPrincipal
done