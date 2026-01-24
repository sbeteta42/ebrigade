# eBrigade : Déploiement automatisé (Debian 11 / PHP 7.4)

[![Debian](https://img.shields.io/badge/Debian-11%20(Bullseye)-A81D33?logo=debian&logoColor=white)](#)
[![Apache](https://img.shields.io/badge/Apache-2.4-D22128?logo=apache&logoColor=white)](#)
[![MariaDB](https://img.shields.io/badge/MariaDB-10.x-003545?logo=mariadb&logoColor=white)](#)
[![PHP](https://img.shields.io/badge/PHP-7.4-777BB4?logo=php&logoColor=white)](#)
[![SSL](https://img.shields.io/badge/HTTPS-self--signed-orange)](#)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

Déploiement **propre et reproductible** de **eBrigade 5.3.2** sur **Debian 11** avec **Apache + MariaDB + PHP 7.4**, création du **VirtualHost**, génération automatique d’un **certificat SSL self-signed** (utile en LAN), et **redirection HTTP → HTTPS**.

> ⚠️ Ce dépôt ne distribue pas eBrigade (application).  
> Il fournit uniquement les scripts et la doc de déploiement.  
> Tu dois disposer du ZIP officiel `ebrigade-5.3.2.zip`.

---

## Sommaire

- [Objectif](#objectif)
- [Pré-requis](#pré-requis)
- [Compatibilité](#compatibilité)
- [Installation rapide](#installation-rapide)
- [Ce que fait le script](#ce-que-fait-le-script)
- [Post-installation](#post-installation)
- [Désinstallation](#désinstallation)
- [Sécurité](#sécurité)
- [Dépannage](#dépannage)
- [Roadmap](#roadmap)
- [Licence](#licence)
- [Crédits](#crédits)

---

## Objectif

✅ Automatiser une installation eBrigade **stable en environnement LAN / formation** :

- Dépendances LAMP cohérentes (Debian 11 / PHP 7.4)
- Déploiement du ZIP dans `/var/www/ebrigade`
- VHost Apache + `.htaccess` (AllowOverride All)
- Base MariaDB + user dédiés
- HTTPS self-signed auto (SAN = domaine)
- HTTP redirigé vers HTTPS

---

## Pré-requis

- Une VM / serveur **Debian 11 (Bullseye)**
- Accès root (`sudo`)
- Un nom DNS interne (ou `/etc/hosts`) : par défaut `formation.lan`
- Le ZIP officiel : `ebrigade-5.3.2.zip`

---

## Compatibilité

- eBrigade **5.3.2** : **PHP 7.0 → 7.4.99** ✅  
- Debian 11 : PHP **7.4** dans les dépôts officiels ✅  
- Debian 12/13 : PHP 8.x ❌ (pas compatible sans bricoler PHP)

---

## Installation rapide

1) Clone le dépôt :

```bash
git clone https://github.com/sbeteta42/ebrigade.git
cd ebrigade
Copie le ZIP eBrigade sur le serveur (ex: /root/ebrigade-5.3.2.zip)
```

2) Lance l’installation :
```bash
chmod +x install-ebrigade.sh
sudo ./install-ebrigade.sh --zip /root/ebrigade-5.3.2.zip
```
### Par défaut :

- Domaine : formation.lan

- Dossier web : /var/www/ebrigade

- DB : ebrigade / user: ebrigade / mot de passe: operations

- Options utiles
sudo ./install-ebrigade.sh \
  --zip /root/ebrigade-5.3.2.zip \
  --domain formation.lan \
  --db-pass "operations"

## Ce que fait le script

- Installe : apache2, mariadb-server, php7.4, modules PHP nécessaires

- Active : rewrite, headers, ssl

- Crée :

Base : ebrigade (utf8mb4)

User : ebrigade@localhost (+ droits complets sur la base)

Déploie le ZIP dans /var/www/ebrigade

Pose un VHost Apache :

:80 → redirect vers https://formation.lan/

:443 → SSL + DocumentRoot eBrigade

Génère un certificat self-signed :

CRT : /etc/ssl/localcerts/formation.lan.crt

KEY : /etc/ssl/private/formation.lan.key

## Post-installation
1) Résolution DNS (LAN)

- Sur tes postes clients (si pas de DNS interne), ajoute dans hosts :

- Linux : /etc/hosts

- Windows : C:\Windows\System32\drivers\etc\hosts

- Exemple : 192.168.X.Y  formation.lan

2) Avertissement navigateur (normal)

Self-signed = warning tant que le certificat n’est pas approuvé.
- Deux options :
  - accepter l’exception (lab/formation)
  - ou mieux : PKI interne (roadmap)

3) Config eBrigade

Selon la distribution, eBrigade se configure via :

- un wizard web
- ou un fichier type config.php

- Le script fournit :

  - DB_NAME : ebrigade

  - DB_USER : ebrigade

  - DB_PASS : affiché en fin d’installation

# Désinstallation

⚠️ Attention, ça supprime fichiers + vhost + base (si tu veux).

- Désactiver le vhost :
```bash
sudo a2dissite ebrigade.conf
sudo systemctl reload apache2
```

## Supprimer les fichiers :
```bash
sudo rm -rf /var/www/ebrigade
sudo rm -f /etc/apache2/sites-available/ebrigade.conf
```

## Supprimer DB + user :
```bash
sudo mysql -u root -e "DROP DATABASE IF EXISTS ebrigade;"
sudo mysql -u root -e "DROP USER IF EXISTS 'ebrigade'@'localhost'; FLUSH PRIVILEGES;"
```
## Sécurité

- Self-signed = OK pour LAN, pas idéal en prod

- Reco prod :

  - Certificat signé par une CA interne ou Let’s Encrypt

  - Durcir php.ini, limiter upload si inutile

  - Sauvegardes DB + répertoire d’upload

  - Mettre eBrigade derrière un reverse-proxy si besoin

  - Journaliser + surveiller les erreurs Apache/PHP

## Dépannage
```bash
Logs Apache
sudo tail -n 80 /var/log/apache2/ebrigade_ssl_error.log
sudo tail -n 80 /var/log/apache2/ebrigade_error.log
```

- Vérifier PHP
```bash
php -v
php -m | egrep 'mysqli|mbstring|xml|gd|zip|curl'
```

- Test VHost
```bash
sudo apache2ctl -S
sudo apache2ctl configtest
```
## Roadmap

 - Mode “PKI interne” (root CA + cert serveur + import Windows/Linux)

- Auto-détection et patch du fichier de config eBrigade (DB_HOST/DB_NAME/…)

 - Support Debian 12 via conteneur PHP 7.4 (Docker/Podman)

 - Backup/restore (DB + uploads) en 2 commandes

## Licence

MIT - voir LICENSE

## Crédits

Scripts & packaging : shadowhacker

eBrigade : appartient à son éditeur (non distribué ici)

Si tu utilises ce dépôt en formation : tu peux le forker et adapter formation.lan, les IP et les paramètres de lab.
