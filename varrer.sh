#!/bin/bash

# Authorized PHP File Scanner for Pentesting
# Usage: ./php_file_scanner.sh <target_url>
#!/usr/bin/env bash
while true;
do

TARGET="$1"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:91.0) Gecko/20100101 Firefox/91.0"
#DIRLIST="/usr/share/wordlists/dirb/common.txt"  # Default wordlist (Kali Linux)
OUTPUT="php_files_found.txt"

read -p "Dgite o diretorio da wordlist: " DIRLIST

echo "[+] Scanning $TARGET for .php files..."
echo "[+] Output will be saved to: $OUTPUT"
echo ""

# Check if curl/wget exists
if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "[!] Error: Install 'curl' or 'wget' first."
    exit 1
fi

# Check if wordlist exists
if [ ! -f "$DIRLIST" ]; then
    echo "[!] Error: Wordlist not found at $DIRLIST"
    echo "[!] Try: sudo apt install wordlists (Kali Linux)"
    exit 1
fi

# Scan function
scan_php_files()
{
    while read -r dir; do
        url="$TARGET/$dir.php"
        if curl -s -A "$USER_AGENT" -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
            echo "[+] Found: $url"
            echo "$url" >> "$OUTPUT"
        fi
    done < "$DIRLIST"
}

# Start scan
scan_php_files

echo ""
echo "[!] Scan completed. Results saved to $OUTPUT."
done
