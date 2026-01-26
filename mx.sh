#!/bin/bash

# ==========================================
# Docker-Mailserver Wrapper
# Simplifie l'utilisation de docker-mailserver
# ==========================================

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-$HOME/mailserver-docker/docker-compose.yml}"
CONTAINER="mailserver"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==========================================
# FONCTIONS UTILITAIRES
# ==========================================

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo -e "${RED}✗ Le conteneur '${CONTAINER}' n'est pas en cours d'exécution${NC}"
        exit 1
    fi
}

setup() {
    check_container
    docker exec -ti "${CONTAINER}" setup "$@"
}

# ==========================================
# AIDE
# ==========================================

print_help() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Docker-Mailserver Management Tool                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}GESTION DES COMPTES EMAIL${NC}"
    echo "  email add <email> [password]        Créer un compte email"
    echo "  email update <email> <password>     Modifier le mot de passe"
    echo "  email del <email>                   Supprimer un compte"
    echo "  email list                          Lister tous les comptes"
    echo "  email restrict <add|del|list>       Gérer les restrictions d'envoi"
    echo ""
    echo -e "${GREEN}GESTION DES ALIAS${NC}"
    echo "  alias add <source> <destination>    Créer un alias"
    echo "  alias del <source> <destination>    Supprimer un alias"
    echo "  alias list                          Lister tous les alias"
    echo "  alias-wizard                        Assistant de création d'alias"
    echo ""
    echo -e "${GREEN}GESTION DES DOMAINES${NC}"
    echo "  config dkim domain <domain>         Configurer DKIM pour un domaine"
    echo "  config dkim keysize <size>          Définir la taille de clé DKIM (1024/2048/4096)"
    echo "  dkim                                Afficher les clés DKIM publiques"
    echo ""
    echo -e "${GREEN}FAIL2BAN${NC}"
    echo "  fail2ban                            Afficher le statut"
    echo "  fail2ban ban <IP>                   Bannir une IP"
    echo "  fail2ban unban <IP>                 Débannir une IP"
    echo "  fail2ban log                        Voir les logs"
    echo ""
    echo -e "${GREEN}RSPAMD (ANTISPAM)${NC}"
    echo "  rspamd stats                        Statistiques antispam"
    echo "  rspamd learn spam <file>            Apprendre un spam"
    echo "  rspamd learn ham <file>             Apprendre un non-spam"
    echo ""
    echo -e "${GREEN}DEBUG${NC}"
    echo "  debug login <email>                 Tester l'authentification"
    echo "  debug show-mail-logs                Afficher les logs mail"
    echo ""
    echo -e "${GREEN}CONFIGURATION${NC}"
    echo "  config                              Vérifier la configuration"
    echo "  relay add <domain> <host> [port]    Ajouter un relay"
    echo "  relay exclude <domain>              Exclure un domaine du relay"
    echo ""
    echo -e "${GREEN}SYSTÈME${NC}"
    echo "  logs [service] [lines]              Voir les logs (défaut: all, 50)"
    echo "  shell                               Ouvrir un shell dans le conteneur"
    echo "  help                                Afficher cette aide"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# ==========================================
# GESTION DES ALIAS
# ==========================================

alias_wizard() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              ASSISTANT DE CRÉATION D'ALIAS                    ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "$(echo -e ${GREEN}Adresse source de l\'alias:${NC} )" source
    read -p "$(echo -e ${GREEN}Adresse de destination:${NC} )" destination
    
    echo ""
    echo -e "${YELLOW}Création de l'alias...${NC}"
    
    if setup alias add "$source" "$destination"; then
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║              ✓ ALIAS CRÉÉ AVEC SUCCÈS                         ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Source:${NC}      $source"
        echo -e "${CYAN}Destination:${NC} $destination"
    else
        echo ""
        echo -e "${RED}✗ Échec de la création de l'alias${NC}"
    fi
    echo ""
}

# ==========================================
# DKIM
# ==========================================

show_dkim() {
    check_container
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              CLÉS PUBLIQUES DKIM                              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Récupérer la liste des domaines avec clés DKIM
    local domains
    domains=$(docker exec "${CONTAINER}" find /tmp/docker-mailserver/opendkim/keys -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || echo "")
    
    if [[ -z "$domains" ]]; then
        echo -e "${YELLOW}⚠ Aucune clé DKIM trouvée${NC}"
        echo ""
        echo -e "${CYAN}Pour générer une clé DKIM :${NC}"
        echo "  mx config dkim domain example.com"
        echo ""
        return
    fi
    
    # Afficher les clés pour chaque domaine
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Domaine: ${BOLD}$domain${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Lire le contenu du fichier mail.txt
        local dkim_content
        dkim_content=$(docker exec "${CONTAINER}" cat "/tmp/docker-mailserver/opendkim/keys/$domain/mail.txt" 2>/dev/null || echo "")
        
        if [[ -n "$dkim_content" ]]; then
            echo -e "${YELLOW}Enregistrement DNS à créer :${NC}"
            echo ""
            echo "$dkim_content"
            echo ""
            
            # Extraire et formater la clé publique pour faciliter la copie
            local dkim_record
            dkim_record=$(echo "$dkim_content" | grep -oP 'p=\K[^"]+' | tr -d '\n' | tr -d ' ')
            
            if [[ -n "$dkim_record" ]]; then
                echo -e "${CYAN}Valeur p= (clé publique) :${NC}"
                echo "$dkim_record"
                echo ""
            fi
        else
            echo -e "${RED}✗ Impossible de lire la clé DKIM${NC}"
            echo ""
        fi
        
    done <<< "$domains"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Pour tester vos enregistrements DKIM :${NC}"
    echo "  dig TXT mail._domainkey.example.com"
    echo "  ou utiliser : https://mxtoolbox.com/dkim.aspx"
    echo ""
}

# ==========================================
# FAIL2BAN
# ==========================================

fail2ban_status() {
    check_container
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              STATUT FAIL2BAN                                  ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    docker exec "${CONTAINER}" fail2ban-client status
    echo ""
    
    echo -e "${YELLOW}Détails des jails actives :${NC}"
    echo ""
    docker exec "${CONTAINER}" fail2ban-client status | grep "Jail list" | sed 's/.*://;s/,//g' | xargs -n1 | while read -r jail; do
        [[ -z "$jail" ]] && continue
        echo -e "${GREEN}═══ $jail ═══${NC}"
        docker exec "${CONTAINER}" fail2ban-client status "$jail"
        echo ""
    done
}

fail2ban_ban() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo -e "${RED}✗ IP requise${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo "  mx fail2ban ban <IP>"
        return 1
    fi
    
    check_container
    docker exec "${CONTAINER}" fail2ban-client set postfix-sasl banip "$ip"
    echo -e "${GREEN}✓ IP $ip bannie${NC}"
}

fail2ban_unban() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo -e "${RED}✗ IP requise${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo "  mx fail2ban unban <IP>"
        return 1
    fi
    
    check_container
    docker exec "${CONTAINER}" fail2ban-client set postfix-sasl unbanip "$ip"
    echo -e "${GREEN}✓ IP $ip débannie${NC}"
}

fail2ban_log() {
    check_container
    docker exec "${CONTAINER}" tail -n 100 /var/log/fail2ban.log
}

# ==========================================
# RSPAMD
# ==========================================

rspamd_stats() {
    check_container
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              STATISTIQUES RSPAMD                              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    docker exec "${CONTAINER}" rspamadm stats
    echo ""
    
    echo -e "${YELLOW}Pour accéder à l'interface web Rspamd :${NC}"
    echo "  http://$(hostname -I | awk '{print $1}'):11334"
    echo ""
}

# ==========================================
# DEBUG
# ==========================================

debug_login() {
    local email="$1"
    if [[ -z "$email" ]]; then
        echo -e "${RED}✗ Email requis${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo "  mx debug login user@example.com"
        return 1
    fi
    
    check_container
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              TEST D'AUTHENTIFICATION                          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Test de connexion pour: ${email}${NC}"
    echo ""
    
    # Demander le mot de passe de manière sécurisée
    read -s -p "$(echo -e ${GREEN}Mot de passe:${NC} )" password
    echo ""
    echo ""
    
    # Test IMAP
    echo -e "${YELLOW}🔍 Test IMAP (port 143 STARTTLS)...${NC}"
    local auth_result
    auth_result=$(docker exec "${CONTAINER}" doveadm auth test "$email" "$password" 2>&1)
    echo "$auth_result"
    echo ""
    
    # Vérifier si le compte existe (méthode améliorée)
    echo -e "${YELLOW}🔍 Vérification du compte...${NC}"
    
    # Méthode 1 : via setup email list (fichiers locaux)
    if docker exec "${CONTAINER}" setup email list 2>/dev/null | grep -q "$email"; then
        echo -e "${GREEN}✓ Le compte existe (stockage local)${NC}"
    
    # Méthode 2 : via les logs d'authentification (preuve d'existence)
    elif echo "$auth_result" | grep -q "auth succeeded"; then
        echo -e "${GREEN}✓ Le compte existe (authentification réussie)${NC}"
    
    # Méthode 3 : via Dovecot userdb
    elif docker exec "${CONTAINER}" doveadm user "$email" &>/dev/null; then
        echo -e "${GREEN}✓ Le compte existe (base utilisateurs Dovecot)${NC}"
    
    else
        echo -e "${RED}✗ Le compte n'existe pas ou n'est pas accessible${NC}"
    fi
    echo ""
    
    # Résultat du test
    if echo "$auth_result" | grep -q "auth succeeded"; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║              ✓ AUTHENTIFICATION RÉUSSIE                       ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║              ✗ ÉCHEC D'AUTHENTIFICATION                       ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    fi
    echo ""
    
    # Dernières connexions
    echo -e "${YELLOW}🔍 Dernières tentatives de connexion (5 plus récentes)...${NC}"
    docker exec "${CONTAINER}" grep "$email" /var/log/mail/mail.log 2>/dev/null | grep -E "(Login|auth)" | tail -5 || echo -e "${YELLOW}Aucune trace trouvée${NC}"
    echo ""
}

show_mail_logs() {
    check_container
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              LOGS MAIL (50 dernières lignes)                  ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    docker exec "${CONTAINER}" tail -n 50 /var/log/mail/mail.log
}

# ==========================================
# CONFIGURATION
# ==========================================

check_config() {
    check_container
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              VÉRIFICATION DE LA CONFIGURATION                 ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}🔍 Test de configuration Postfix...${NC}"
    docker exec "${CONTAINER}" postfix check && echo -e "${GREEN}✓ Configuration Postfix OK${NC}" || echo -e "${RED}✗ Erreur dans la configuration Postfix${NC}"
    echo ""
    
    echo -e "${YELLOW}🔍 Test de configuration Dovecot...${NC}"
    docker exec "${CONTAINER}" doveconf > /dev/null && echo -e "${GREEN}✓ Configuration Dovecot OK${NC}" || echo -e "${RED}✗ Erreur dans la configuration Dovecot${NC}"
    echo ""
    
    echo -e "${YELLOW}🔍 Services actifs...${NC}"
    docker exec "${CONTAINER}" supervisorctl status
    echo ""
}

# ==========================================
# LOGS
# ==========================================

show_logs() {
    local service="${1:-all}"
    local lines="${2:-50}"
    
    check_container
    
    case "$service" in
        mail)
            docker exec "${CONTAINER}" tail -n "$lines" /var/log/mail/mail.log
            ;;
        postfix)
            docker exec "${CONTAINER}" tail -n "$lines" /var/log/mail/mail.log | grep postfix
            ;;
        dovecot)
            docker exec "${CONTAINER}" tail -n "$lines" /var/log/mail/mail.log | grep dovecot
            ;;
        rspamd)
            docker exec "${CONTAINER}" tail -n "$lines" /var/log/supervisor/rspamd.log
            ;;
        fail2ban)
            docker exec "${CONTAINER}" tail -n "$lines" /var/log/fail2ban.log
            ;;
        all|*)
            echo -e "${CYAN}═══ LOGS DOCKER COMPOSE ═══${NC}"
            docker compose -f "$COMPOSE_FILE" logs --tail="$lines" mailserver
            ;;
    esac
}

# ==========================================
# ROUTEUR PRINCIPAL
# ==========================================

case "${1:-}" in
    email|alias|quota|config)
        setup "$@"
        ;;
    
    alias-wizard)
        alias_wizard
        ;;
    
    dkim)
        show_dkim
        ;;
    
    fail2ban)
        shift
        case "${1:-}" in
            ban)
                shift
                fail2ban_ban "$@"
                ;;
            unban)
                shift
                fail2ban_unban "$@"
                ;;
            log)
                shift
                fail2ban_log "$@"
                ;;
            "")
                fail2ban_status
                ;;
            *)
                echo -e "${RED}✗ Commande fail2ban invalide${NC}"
                print_help
                exit 1
                ;;
        esac
        ;;
    
    rspamd)
        shift
        case "${1:-}" in
            stats)
                rspamd_stats
                ;;
            learn)
                setup rspamd "$@"
                ;;
            *)
                echo -e "${RED}✗ Commande rspamd invalide${NC}"
                print_help
                exit 1
                ;;
        esac
        ;;
    
    debug)
        shift
        case "${1:-}" in
            login)
                shift
                debug_login "$@"
                ;;
            show-mail-logs)
                show_mail_logs
                ;;
            *)
                setup debug "$@"
                ;;
        esac
        ;;
    
    relay)
        setup "$@"
        ;;
    
    logs)
        shift
        show_logs "$@"
        ;;
    
    shell)
        check_container
        docker exec -ti "${CONTAINER}" /bin/bash
        ;;
    
    help|--help|-h|"")
        print_help
        ;;
    
    *)
        echo -e "${RED}✗ Commande inconnue: $1${NC}"
        echo ""
        print_help
        exit 1
        ;;
esac
