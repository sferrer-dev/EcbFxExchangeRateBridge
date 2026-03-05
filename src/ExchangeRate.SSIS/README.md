# 📦 ExchangeRate.SSIS

> **Integration Services Project (SSIS)**  
> Conception d’un pipeline ETL – SQL Server 2019  
> Solution : *EcbFxReference*

## 🎯 Objectif du projet

Dans un contexte multi-bases (**ExchangeRatesDB** technique et **SalesMgmtDB** métier), ce projet met en place une chaîne d’intégration permettant de :
- Télécharger les taux de change journaliers depuis l’API de la Banque Centrale Européenne (ECB)
- Charger et historiser les données dans la base ExchangeRatesDB
- Exposer un taux exploitable par la base métier SalesMgmtDB
- Orchestrer les traitements quotidiens et mensuels

## 🏗 Architecture du projet

```
ECB API (XML / CSV)
        │
        ▼
SSIS (ExchangeRate.SSIS)
        │
        ├── ExchangeRatesDB (base technique / historisation)
        │
        └── SalesMgmtDB (base métier cible)
```

Le projet est structuré selon la logique :  
- Base technique : stockage brut et historisé des taux
- Base métier : consommation applicative
- SSIS : couche d’intégration et d’orchestration

### 🔄 Stratégie ETL

#### Ingestion

- Appel API ECB
- Parsing CSV
- Chargement incrémental
- Gestion des rejets
- Idempotence
- Rejeu contrôlé via paramètres override
- Historisation complète

#### Historisation

- Table exchange_rates_daily : Clé series_key + time_period
- Index optimisé sur (series_key, time_period DESC)
- Production d’un taux tarifaire avec fallback.

<p align="center">• • •</p>

## 📁 Structure des packages SSIS

### 🔹 04_Master_EcbDailyExchangeRate.dtsx

Package orchestrateur principal, conçu pour une exécution planifiée via un ordonnanceur (ex. SQL Server Agent).  
Il pilote la chaîne ETL “ECB Daily Exchange Rate” de bout en bout en garantissant l’ordre d’exécution, la cohérence fonctionnelle et la traçabilité (logs).  
Il est responsable de :
- Exécute les packages enfants dans le bon ordre (contrôle de flux)
- Initialise
- Charge le référentiel devises
- Télécharge les taux journaliers
- Déclenche les traitements mensuels
- Gère les conditions d’exécution

#### 🔹 01_Init_EcbDailyExchangeRate.dtsx

Initialisation du contexte d’exécution :
- Vérification des dossiers
- Préparation des variables
- Paramétrage global

#### 🔹 02_Load_CurrencyRef_FromXml.dtsx

Charge le référentiel de toutes les devises depuis :  
`https://data-api.ecb.europa.eu/service/codelist/ECB/CL_CURRENCY`

Objectif :
- Maintenir une table de référence des codes devises

#### 🔹 02_Load_EcbSeriesKeyRef_ForEuro.dtsx

Charge le référentiel des devises depuis :  
`https://data-api.ecb.europa.eu/service/data/EXR/`  
avec la clé de série `A..EUR.SP00.A` pour n’obtenir que les séries exprimées contre l’euro.

Objectif :
- Garantir la cohérence des séries téléchargées

#### 🔹 02_Load_EcbDailyExchangeRates.dtsx

Télécharge les taux journaliers ECB :  
`https://data-api.ecb.europa.eu/service/data/EXR/`
avec une clé de série `D.{currency_code}.EUR.SP00.A` pour obtenir une devise spécifique contre l’euro .

Responsabilités :
- Téléchargement des fichiers CSV
- Parsing CSV
- Chargement des fichiers CSV dans la base technique
- Gestion de l’historisation

#### 🔹 03_Load_EcbDailyExchangeRate_ForSeriesKey.dtsx

Traitement unitaire par series_key.  
Utilisé pour :
- Chargement des données dans dbo.exchange_rates_daily
- Rejeu technique

#### 🔹 02_Load_TariffRates_Monthly.dtsx

Calcul d’un taux exploitable mensuellement pour le métier.
- Fallback 90 → 60 → 30 jours
- Sinon dernier taux connu

### 🔹 04_Master_Devise.dtsx

Second package orchestrateur destiné à être exécuté par un ordonnanceur (ex : SQL Server Agent).  
Il assure l’orchestration de bout en bout de la synchronisation des devises entre la base technique (taux ECB) et la base métier (référentiel + historique).  
Il est responsable de :
- Exécuter les packages enfants dans le bon ordre (contrôle de flux)
- Synchroniser l’historique métier
- Mettre à jour des devises (taux courants)

#### 🔹 02_Load_DevisesHistory.dtsx

Charge l’historique complet des devises depuis la base technique vers la base métier, avec un mapping sur le référentiel de devises pour garantir la cohérence des données.
Ce package est conçu pour appliquer upsert/merge.

👉 Concrètement :
- Il charge les taux par devise et par date
- Détecte si l’historique existe déjà (DevisesExist).
- Si vide → charger en full via usp_Merge_DevisesHisto_FromEcbDaily sans paramètres.
- Sinon → auditer la plage [pMinLastRateDate ; pAsOfDate].
- Si anomalies > 0 → exécuter un merge incrémental sur la même plage.

**Paramètres de package** :
- pAsOfDate (DT_DATE) : date “as-of” (aujourd’hui côté orchestrateur parent).
- pMinLastRateDate (DT_DATE) : date de départ pour la synchronisation incrémentale (le “from date”).

👉 Ces deux paramètres sont utilisés pour :
- l’audit (fonction fn_Audit_EcbVsDevisesHisto(?, ?)),
- et la synchro incrémentale (proc usp_Merge_DevisesHisto_FromEcbDaily ?, ?).

**Variables** :
- User::DevisesExist (DT_BOOL) : drapeau “la table DEVISES_HISTO contient déjà des données”.
- User::AuditErrorCount (DT_I4) : nombre d’anomalies détectées entre source et cible sur la plage.

#### 🔹 02_Load_Devise.dtsx

Ce package met à jour la table SalesMgmtDB.dbo.DEVISES (les devises “actives/suivies”) à partir de ce qui a déjà été chargé dans SalesMgmtDB.dbo.DEVISES_HISTO via les vues de taux appelées indirectement par la proc.  
Il charge les devises dans la base métier SalesMgmtDB pour une consommation applicative.

👉 Concrètement :
- il valide d’abord que DEVISES_HISTO et la source ECB sont cohérentes,
- puis il exécute une procédure de synchronisation des taux “courants” dans DEVISES,
- et enfin il journalise rows_updated.

**Paramètres de package** :
- pAsOfDate (DT_DATE) : date “as-of” (aujourd’hui côté orchestrateur parent).
- pMinLastRateDate (DT_DATE) : borne basse de contrôle (from date).

**Variables** :
- AuditErrorCount : nombre d’anomalies détectées.
- RowsUpdated : nombre de devises effectivement mises à jour (retour de proc).

## ⚙️ Paramètres Projet

Le projet est piloté par des Project Parameters, notamment :

|Paramètre|Rôle|
|---------|----|
| `pExchangeRateDb_ConnectionString` | Connexion base technique |
| `pSalesMgmtDb_ConnectionString`	|Connexion base métier |
| `pEcbDataApiBaseUrl` | Endpoint API ECB (EXR) |
| `pEcbCurrencyCodelistApiUrl` | Endpoint référentiel devises |
| `pDataRoot` | Répertoire racine des données |
| `pInFolder` | Gestion des flux fichiers |
| `pStartPeriodOverride` | Rejeu manuel |
| `pEndPeriodOverride` | Rejeu manuel |

👉 Tous les Connection Managers sont pilotés dynamiquement par ces paramètres.

## 🗄️ Bases de données concernées

**ExchangeRatesDB**  
Base technique contenant historisation complète et traçabilité.

**SalesMgmtDB**  
Base métier cible pour fournir un taux exploitable pour une gestion commerciale avec des calculs tarifaires.

<p align="center">• • •</p>

## 📊 Logique métier du taux tarifaire

Hiérarchie de fallback :  
1. Moyenne stable 90 jours
2. Sinon moyenne 60 jours
3. Sinon moyenne 30 jours
4. Sinon dernier taux connu

## 🚀 Déploiement

Le projet est déployé sous forme d’ISPAC dans SSISDB :  
- Environnements : DEV / UAT / PROD
- Paramètres mappés aux variables d’environnement
