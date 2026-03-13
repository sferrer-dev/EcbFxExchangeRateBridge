# 💱 EcbFxReference / EcbFxExchangeRateBridge

> Solution Data – Référentiel de taux de change ECB

## 🎯 Vision globale

Ce projet est une solution de gestion et d’exploitation des taux de change de la Banque Centrale Européenne (ECB).

Elle couvre l’ensemble du cycle de vie des données :

📥 Ingestion depuis l’API ECB  
🗄️ Stockage et historisation technique  
🧠 Calcul d’indicateurs métier  
💼 Exposition vers une base cible métier  
📊 Analyse exploratoire des données

La solution est structurée selon une approche architecture data en couches.

## 📦 Composition de la solution
```
EcbFxReference
├── ExchangeRate.SSIS
├── ExchangeRate.Database
├── SalesMgmt.Database
└── ExchangeRate.EDA
```

## 📌 Prérequis techniques :

- SQL Server 2019 Developer Edition
- Visual Studio 2022
- Extension SQL Server Data Tools (SSDT)
- Extension SQL Server Integration Services Projects (SSIS)

## 🔄 ExchangeRate.SSIS

**Integration Services Project (ETL)**  
👉 [README.md](src/ExchangeRate.SSIS/README.md)

**Rôle**  
Orchestration du pipeline d’intégration.

**Responsabilités**  
- Téléchargement des taux ECB
- Parsing CSV / XML
- Chargement incrémental
- Historisation dans ExchangeRatesDB
- Calcul mensuel de taux tarifaires
- Pilotage via paramètres projet
- Déploiement en ISPAC dans SSISDB

🎯 Cette couche représente le moteur d’intégration.

## 🗄️ ExchangeRate.Database

**SQL Server Database Project (SSDT)**  
👉 [README.md](src/ExchangeRate.Database/README.md)

**Rôle**  
Base technique historisée : ExchangeRatesDB

**Responsabilités**  
- Stockage brut des observations journalières
- Paramétrage dynamique des séries (exchange_rate_series)
- Calcul des taux stables (30/60/90 jours)
- Exposition via vues métier
- Optimisation via index dédiés
- Approche Database-as-Code
- Déploiement reproductible
- Séparation technique / métier

🎯 Cette base constitue la couche persistence et calcul.

## 🗄️ SalesMgmt.Database

**SQL Server Database Project (SSDT)**  
👉 [README.md](src/SalesMgmt.Database/README.md)

**Rôle**  
Base cible métier : SalesMgmtDB

**Responsabilités**  
- Modèle compatible ERP / Sales
- Référentiel devises métier
- Historisation côté exploitation

Flux logique :
```
ECB → SSIS → ExchangeRatesDB → SalesMgmtDB
```

🎯 Cette base représente la couche métier exploitable.

## 🔎 Requêtes API – Collection Postman

Une **collection Postman** est fournie afin de faciliter l’exploration et le test des endpoints du **ECB Data Portal API** utilisés dans ce projet.
Elle permet notamment d’identifier les séries de taux disponibles, d’interroger les historiques de change et de récupérer les métadonnées nécessaires au paramétrage du référentiel.

La collection est disponible ici : [`ecb-fx-data-api.postman_collection.json`](docs/postman/ecb-fx-data-api.postman_collection.json)

Une documentation dédiée explique comment importer et utiliser ces requêtes dans Postman :

👉 [docs/postman/README.md](docs/postman/README.md)

Cette collection constitue un **outil de support pour le développement et la maintenance du pipeline ETL**, en permettant de reproduire facilement les appels API utilisés par les packages SSIS.


### Vérification des chargements SSIS et contrôle qualité des données

Le script SQL [`verify-ssis-load-and-data-quality.sql`](docs/sql/runbooks/verify-ssis-load-and-data-quality.sql) est un **runbook d’audit et de contrôle post-exécution** destiné à vérifier l’intégrité des données après l’exécution des packages SSIS du projet. Il permet de contrôler la cohérence des taux de change ingérés dans **ExchangeRatesDB**, de comparer les valeurs exposées dans **SalesMgmtDB**, et de détecter rapidement d’éventuelles anomalies entre les données de référence publiées par la **Banque Centrale Européenne (ECB)** et les données stockées dans la table métier `DEVISES_HISTO`. Le script produit des résultats directement exploitables (synthèses, comparaisons de derniers taux, taux stables 30/60/90 jours, audit détaillé des écarts) et peut être utilisé comme **outil opérationnel de validation des chargements ETL et de diagnostic de la qualité des données**. :contentReference[oaicite:0]{index=0}

## 📊 ExchangeRate.EDA

**Projet d’Analyse Exploratoire (R)**  
👉 [README.md](src/ExchangeRate.EDA/README.md)

**Rôle**  
Analyse exploratoire des taux de change.

**Objectifs**  
- Vérification qualité des données
- Statistiques descriptives
- Détection anomalies
- Visualisations temporelles
- Profilage batch des CSV

**Technologies**  
- R / RStudio
- tidyverse
- ggplot2
- rmarkdown
- Génération automatisée de rapports HTML

🎯 Cette couche est la dimension analytique de la solution.
