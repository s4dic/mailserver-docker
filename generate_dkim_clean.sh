#!/bin/bash

# Chemins
DOCKER_CMD="docker exec -ti mailserver setup config dkim"
KEYS_DIR="./docker-data/dms/config/opendkim/keys"

echo "=== 1. Génération des clés DKIM ==="
# On relance la génération (si les clés existent déjà, il ne les écrase pas sauf si supprimées)
$DOCKER_CMD
echo ""

echo "=== 2. Lecture et Formatage pour DNS ==="
echo "------------------------------------------------------------------------------------"

# On cherche tous les fichiers mail.txt
find "$KEYS_DIR" -name "mail.txt" | sort | while read -r keyfile; do
    
    # Extraction du nom de domaine depuis le dossier parent
    DOMAIN=$(basename "$(dirname "$keyfile")")
    
    # Extraction et nettoyage de la valeur
    # 1. grep -o : prend ce qu'il y a entre guillemets
    # 2. tr -d : supprime les guillemets
    # 3. tr -d : supprime les retours à la ligne pour en faire une seule longue chaîne
    VALUE=$(grep -o '"[^"]*"' "$keyfile" | tr -d '"' | tr -d '\n')

    echo "Domaine : $DOMAIN"
    echo "Type    : TXT"
    echo "Nom     : mail._domainkey"
    echo "Valeur  : $VALUE"
    echo ""
    echo "------------------------------------------------------------------------------------"
done
