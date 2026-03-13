# ECB FX Data API – Collection Postman

Ce dépôt contient une **collection Postman** de requêtes permettant d’interroger l’API du portail de données de la **Banque centrale européenne** afin de récupérer des **taux de change (Foreign Exchange – FX)** et des **métadonnées associées**.

Ces requêtes illustrent comment utiliser l’API **SDMX du Data Portal de la BCE** pour récupérer :

* les taux de change quotidiens
* les séries historiques de taux de change
* les métadonnées de séries de change
* la liste des devises de référence
* les clés de séries disponibles

Cette collection est utilisée dans le projet **EcbFxReference** pour alimenter les processus **ETL** et les modèles de données de la base SQL.

---

# Source des données

Les données de taux de change sont fournies par la **Banque centrale européenne (ECB)** via le **ECB Data Portal API**.

Jeu de données utilisé :

* **EXR** – ECB Foreign Exchange Reference Rates

Documentation officielle de l’API :

https://data.ecb.europa.eu/help/api

---

# Collection Postman

Nom de la collection :

```text
ECB FX Data API
```

Cette collection peut être importée directement dans Postman.

---

# Import de la collection

1. Ouvrir **Postman**
2. Cliquer sur **Import**
3. Sélectionner le fichier :

```text
ecb-fx-data-api.postman_collection.json
```

4. Les requêtes apparaîtront dans votre workspace Postman.

---

# Requêtes disponibles

## Données de taux de change

### Taux de change EUR/USD quotidiens (année 2025)

Retourne les taux de change quotidiens EUR/USD pour l'année 2025.

```
GET /service/data/EXR/D.USD.EUR.SP00.A
```

Exemple :

```
https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?startPeriod=2025-01-01&endPeriod=2025-12-31&format=csvdata
```

---

### Historique complet des taux EUR/USD

Retourne la série historique complète du taux de change EUR/USD.

```
https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?format=csvdata
```

---

### Historique complet des taux EUR/CNY

Retourne la série historique complète du taux de change EUR/CNY.

```
https://data-api.ecb.europa.eu/service/data/EXR/D.CNY.EUR.SP00.A?format=csvdata
```

---

### Historique EUR/USD et EUR/CNY dans une même requête

Permet de récupérer deux séries de change dans une seule requête.

```
https://data-api.ecb.europa.eu/service/data/EXR/D.USD+CNY.EUR.SP00.A?format=csvdata
```

---

### Taux EUR/USD sur une période donnée

Retourne les taux EUR/USD pour une période spécifique.

```
https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?startPeriod=2025-01-01&endPeriod=2025-12-31&format=csvdata
```

---

# Métadonnées et données de référence

## Liste officielle des devises

Retourne la **liste officielle des devises** définies par la BCE.

```
https://data-api.ecb.europa.eu/service/codelist/ECB/CL_CURRENCY
```

Format retourné :

**SDMX XML**

---

## Clés de séries FX disponibles contre EUR

Retourne la liste des **Series Keys** disponibles pour les taux de change contre l’euro.

```
https://data-api.ecb.europa.eu/service/data/EXR/D..EUR.SP00.A?format=csvdata&detail=serieskeysonly
```

---

## Métadonnées des séries FX contre EUR (sans données)

Retourne les **métadonnées des séries de change** sans les observations.

```
https://data-api.ecb.europa.eu/service/data/EXR/D..EUR.SP00.A?format=csvdata&detail=nodata
```

---

## Catalogue des séries FX contre EUR (CSV)

Retourne le catalogue complet des séries de taux de change contre EUR avec leurs attributs.

```
https://data-api.ecb.europa.eu/service/data/EXR/D..EUR.SP00.A?detail=nodata&format=csvdata
```

---

# Utilisation dans ce projet

Ces requêtes sont utilisées pour :

* identifier les séries de change disponibles dans l’API ECB
* récupérer les données historiques de taux de change
* alimenter les tables de référence de la base de données
* fournir les données sources des pipelines ETL (SSIS)

Les données récupérées sont ensuite stockées et traitées dans le composant :

```
ExchangeRate.Database
```

du projet **EcbFxReference**.

---

# Licence et source des données

Les données sont fournies par la **Banque centrale européenne (ECB)** et sont soumises aux conditions d’utilisation du portail de données de la BCE.

Pour plus d’informations :

https://data.ecb.europa.eu
