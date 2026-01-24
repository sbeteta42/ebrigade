# eBrigade — Déploiement automatisé (Debian 11 / PHP 7.4)

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
git clone https://github.com/<ton-user>/<ton-repo>.git
cd <ton-repo>
