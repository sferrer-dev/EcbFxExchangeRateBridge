using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace EcbFxExchangeRate.SSIS.ScriptTasks
{
    /*
        --------------------------------------------------------------------
        Classe : EcbHttpDownloader
        --------------------------------------------------------------------
        Objectif :
        Télécharger un fichier distant (ex : dataset ECB) via HTTP
        et l’enregistrer sur le disque local.
        Cette classe est utilisée dans une Script Task SSIS afin
        d'isoler la logique réseau du ScriptMain.cs.
        Avantages :
        - code plus lisible
        - logique réutilisable
        - meilleure maintenabilité du package SSIS
        --------------------------------------------------------------------
    */
    internal sealed class EcbHttpDownloader
    {
        /*
            Méthode principale de téléchargement.

            url          : adresse HTTP du fichier à télécharger
            downloadPath : chemin local où enregistrer le fichier

            Le téléchargement est asynchrone afin de ne pas bloquer
            inutilement le thread de la Script Task.
        */
        public async Task DownloadAsync(string url, string downloadPath)
        {
            // Vérifie la validité des paramètres fournis
            ValidateInputs(url, downloadPath);

            // Configure les paramètres de sécurité réseau (.NET)
            ConfigureSecurity();

            // Vérifie que le dossier cible existe
            EnsureTargetDirectoryExists(downloadPath);

            /*
                Création du HttpClient.

                HttpClient est la classe standard .NET pour faire
                des appels HTTP (API REST, téléchargement de fichiers, etc.).
            */
            using (var http = CreateHttpClient())

            /*
                GetAsync avec ResponseHeadersRead :
                - permet de commencer la lecture du flux immédiatement
                - évite de charger tout le fichier en mémoire
                - idéal pour les téléchargements de fichiers (pattern streaming)
            */
            using (HttpResponseMessage response = await http
                .GetAsync(url, HttpCompletionOption.ResponseHeadersRead)
                .ConfigureAwait(false))
            {
                /*
                    Vérification du statut HTTP.

                    Si la requête retourne une erreur (404, 500, etc.)
                    on lève explicitement une exception détaillée.
                */
                if (!response.IsSuccessStatusCode)
                {
                    // Lecture partielle du contenu retourné (si disponible)
                    string bodySnippet = await SafeReadSnippetAsync(response).ConfigureAwait(false);

                    throw new HttpRequestException(
                        "HTTP " + (int)response.StatusCode +
                        " (" + response.ReasonPhrase + "). " +
                        "URL=" + url + ". " +
                        "Réponse (extrait)=" + bodySnippet);
                }

                /*
                    Lecture du flux HTTP sous forme de Stream.

                    Cela permet de traiter le fichier en streaming
                    sans le charger entièrement en mémoire.
                */
                using (Stream contentStream = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))

                /*
                    Création du fichier cible.

                    FileMode.Create :
                    - écrase le fichier s’il existe déjà
                */
                using (FileStream fileStream = new FileStream(
                    downloadPath,
                    FileMode.Create,
                    FileAccess.Write,
                    FileShare.None))
                {
                    /*
                        Copie du flux HTTP vers le fichier.

                        Pattern classique :
                        Stream HTTP -> FileStream disque
                    */
                    await contentStream.CopyToAsync(fileStream).ConfigureAwait(false);
                }
            }
        }

        /*
            Vérifie les paramètres d'entrée.

            Dans un contexte ETL, valider les entrées évite
            des erreurs difficiles à diagnostiquer dans SSIS.
        */
        private static void ValidateInputs(string url, string downloadPath)
        {
            if (string.IsNullOrWhiteSpace(url))
                throw new ArgumentException("Le paramètre url est vide.");

            if (string.IsNullOrWhiteSpace(downloadPath))
                throw new ArgumentException("Le paramètre downloadPath est vide.");
        }

        /*
            Configuration du protocole de sécurité réseau.

            TLS 1.2 est requis par la plupart des API modernes
            (dont les services de la Banque Centrale Européenne).
        */
        private static void ConfigureSecurity()
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

            // Désactive une optimisation HTTP peu utile ici
            ServicePointManager.Expect100Continue = false;
        }

        /*
            Vérifie que le dossier cible existe.

            Si le dossier n'existe pas, il est créé automatiquement.
            Cela évite les erreurs "Directory not found".
        */
        private static void EnsureTargetDirectoryExists(string downloadPath)
        {
            string dir = Path.GetDirectoryName(downloadPath);

            if (!string.IsNullOrWhiteSpace(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
        }

        /*
            Création et configuration du client HTTP.

            Bonnes pratiques appliquées :
            - timeout défini
            - headers Accept explicites
            - User-Agent identifié
        */
        private static HttpClient CreateHttpClient()
        {
            var http = new HttpClient
            {
                // Temps maximum d’attente de la requête
                Timeout = TimeSpan.FromSeconds(60)
            };

            /*
                Headers HTTP Accept

                On indique au serveur les formats que l'on accepte.
                Ici principalement CSV ou texte brut.
            */
            http.DefaultRequestHeaders.Accept.Clear();
            http.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("text/csv"));
            http.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("text/plain"));

            /*
                User-Agent

                Permet au serveur d’identifier le client.
                Utile pour :
                - debugging
                - logs serveur
            */
            http.DefaultRequestHeaders.UserAgent.ParseAdd("SSIS-ScriptTask/1.0");

            return http;
        }

        /*
            Lecture sécurisée du contenu retourné par le serveur.

            Si une erreur HTTP se produit, on tente de lire
            une partie du contenu pour faciliter le diagnostic.

            La lecture est limitée à 300 caractères afin
            d'éviter des messages d'erreur trop volumineux.
        */
        private static async Task<string> SafeReadSnippetAsync(HttpResponseMessage response)
        {
            try
            {
                string content = await response.Content.ReadAsStringAsync().ConfigureAwait(false);

                if (string.IsNullOrEmpty(content))
                    return "<vide>";

                return content.Length <= 300
                    ? content
                    : content.Substring(0, 300) + "...";
            }
            catch
            {
                // Si le contenu ne peut pas être lu
                return "<impossible de lire le contenu>";
            }
        }
    }
}
