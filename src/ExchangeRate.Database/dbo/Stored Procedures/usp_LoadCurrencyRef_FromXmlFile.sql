/*
    Procédure ETL – Référentiel devises ECB
    Source : fichier XML SDMX (Codelist CL_CURRENCY)
    Usage : appelée depuis un package SSIS (OLE DB Source / Execute SQL Task)
*/
CREATE PROCEDURE dbo.usp_LoadCurrencyRef_FromXmlFile
    @FilePath nvarchar(4000)  -- Chemin absolu vers le fichier XML SDMX (visible par le service SQL Server)
AS
BEGIN
    SET NOCOUNT ON;           -- Évite le retour des messages "n lignes affectées"

    -- Exposition du schéma pour les outils (SSIS, IntelliSense, etc.)
    IF 1 = 0
    BEGIN
        SELECT
            CAST(NULL AS nchar(3))       AS currency_code,
            CAST(NULL AS nvarchar(200))  AS currency_name;
    END

    DECLARE @sql nvarchar(max);  -- Contiendra la requête SQL dynamique

    /*
        OPENROWSET(BULK ...) n'accepte pas de variable pour le chemin du fichier.
        On construit donc dynamiquement la requête SQL en injectant le chemin
        sous forme de littéral sécurisé (QUOTENAME).
    */
    SET @sql = N'
        DECLARE @xml xml;  -- Variable XML pour stocker le contenu du fichier SDMX

        /*
            Lecture du fichier XML SDMX (Codelist ECB) depuis le système de fichiers.
            Le fichier doit être accessible par le compte du service SQL Server.
        */
        SELECT @xml = BulkColumn
        FROM OPENROWSET(
            BULK ' + QUOTENAME(@FilePath, '''') + N',
            SINGLE_BLOB
        ) AS x;

        /*
            Déclaration des namespaces SDMX nécessaires pour interroger le XML
            - str : structure SDMX (Codelist, Code, etc.)
            - com : éléments communs (Name, attributs, etc.)
        */
        WITH XMLNAMESPACES (
          ''http://www.sdmx.org/resources/sdmxml/schemas/v2_1/structure'' AS str,
          ''http://www.sdmx.org/resources/sdmxml/schemas/v2_1/common'' AS com
        )
        /*
            Extraction des codes devises et de leur libellé à partir de la Codelist CL_CURRENCY.
            Les codes techniques (_T, _X, _Z) sont exclus car ils ne correspondent pas
            à de vraies devises ISO utilisables.
        */
        SELECT
            T.c.value(''@id'', ''nchar(3)'')                    AS currency_code,
            T.c.value(''(com:Name/text())[1]'', ''nvarchar(200)'') AS currency_name
        FROM @xml.nodes(''//str:Codelist[@id="CL_CURRENCY"]/str:Code'') AS T(c)
        WHERE LEN(RTRIM(c.value(''@id'', ''nchar(3)''))) = 3;
    ';

    -- Exécution de la requête SQL dynamique
    EXEC sys.sp_executesql @sql;
END
