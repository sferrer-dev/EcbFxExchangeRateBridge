# 📊 ExchangeRate.EDA

## 📌 Description du projet

**ExchangeRate.EDA** est un projet d’**analyse exploratoire de données** réalisé en **R**.  
Il a pour objectif d’analyser l’évolution des **taux de change journaliers** entre l’euro (EUR) et plusieurs devises, notamment le **dollar américain (USD)** et le **yuan chinois (CNY)**, à partir de données officielles de la **Banque Centrale Européenne (ECB)**.

Ce projet vise à :
- comprendre la structure des données,
- détecter d’éventuelles anomalies,
- préparer les données pour des analyses ou modèles ultérieurs.

---

## 🎯 Objectifs de l’EDA

L’analyse exploratoire permet de répondre aux questions suivantes :

- Quelle est la période couverte par les données ?
- Les données contiennent-elles des valeurs manquantes ou aberrantes ?

---

## 📂 Données utilisées

- **Source** : Banque Centrale Européenne (ECB)
- **Format** : CSV
- **Fréquence** : Journalière
- **Variables principales** :
  - Date
  - Taux de change EUR → USD
  - Taux de change EUR → CNY

> Les données sont considérées comme fiables et adaptées à des analyses financières.

### Source des données (format CSV)

Les données analysées dans ce projet proviennent directement de la **Banque Centrale Européenne (ECB)** et ont été récupérées **au format CSV** via l’API officielle de diffusion des données statistiques.

Les fichiers CSV ont été téléchargés en appelant les endpoints suivants :

- Taux de change journalier **EUR / CNY**  
  https://data-api.ecb.europa.eu/service/data/EXR/D.CNY.EUR.SP00.A?format=csvdata

- Taux de change journalier **EUR / USD**  
  https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?format=csvdata

Chaque endpoint retourne une série temporelle officielle, mise à jour par la BCE, contenant les taux de change de référence quotidiens.  
Le paramètre `format=csvdata` permet d’obtenir les données dans un format tabulaire directement exploitable dans R.

---

## 🛠️ Technologies et outils

- **Langage** : R
- **Environnement** : RStudio
- **Packages principaux** :
  - `tidyverse` (manipulation et nettoyage des données)
  - `lubridate` (gestion des dates)
  - `ggplot2` (visualisation)
  - `skimr` / `summary()` (statistiques descriptives)

---

## 🔍 Étapes de l’analyse

Le projet suit une méthodologie EDA standard :

1. **Chargement des données**
   - Import du fichier CSV
   - Vérification de la structure (`str`, `head`)

2. **Nettoyage et préparation**
   - Conversion des dates
   - Gestion des valeurs manquantes
   
3. **Analyse descriptive**
   - Statistiques de base (min, max, moyenne, médiane)

---

## 🧾 Génération des rapports HTML

Le projet intègre un mécanisme de **génération automatisée de rapports HTML** à partir des scripts R Markdown, afin de produire des livrables partageables.

La production des rapports s’effectue via le script **`render.R`**, exécuté depuis **RStudio**, qui centralise les appels à la fonction `rmarkdown::render()`.

### Principe de fonctionnement

- Les fichiers source (`.Rmd`) contiennent :
  - le code d’analyse,
  - les visualisations,
  - les commentaires interprétatifs.
- Le script `render.R` orchestre la génération des rapports en :
  - définissant les chemins d’entrée et de sortie,
  - assurant la reproductibilité du rendu,
  - standardisant le format de sortie.

Les rapports générés sont automatiquement déposés dans le dossier :

Ce dossier est volontairement utilisé afin de :
- faciliter l’hébergement statique (GitHub Pages),
- séparer les livrables finaux du code source,
- garantir une structure projet claire et maintenable.

### Exécution depuis RStudio

Depuis RStudio, la génération des rapports s’effectue en exécutant le script : docs/

```r
source("render.R")
```

## ⚙️ Profilage batch des fichiers CSV

Le projet met en œuvre une fonction R personnalisée nommée **`profile_csv()`**, conçue pour réaliser un **profilage automatisé et standardisé de fichiers CSV** dans un contexte d’analyse exploratoire de données.

### Objectif de la fonction

La fonction `profile_csv()` permet de :
- analyser la structure des fichiers CSV (types de variables, dimensions),
- produire des statistiques descriptives de premier niveau,
- identifier les valeurs manquantes, incohérences ou anomalies potentielles,
- homogénéiser le diagnostic qualité des données avant analyse.

### Utilisation en mode batch

La fonction est spécifiquement utilisée en **mode batch**, c’est-à-dire appliquée de manière itérative à un ensemble de fichiers CSV, sans intervention manuelle.

Le principe est le suivant :
- un répertoire source contenant plusieurs fichiers CSV est parcouru,
- chaque fichier est traité séquentiellement par `profile_csv()`,
- les résultats de profilage sont générés de façon systématique et reproductible.