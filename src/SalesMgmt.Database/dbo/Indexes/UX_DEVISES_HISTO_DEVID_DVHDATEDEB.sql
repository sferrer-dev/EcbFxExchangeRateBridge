/*
    DEVISES_HISTO a une PK sur DVHID (identity), mais aucune unicité sur la clé métier (DEVID, DVHDATEDEB).
    Objectif :
    - Sécuriser l’UPSERT et éviter toute duplication fonctionnelle.
*/
CREATE UNIQUE NONCLUSTERED INDEX [UX_DEVISES_HISTO_DEVID_DVHDATEDEB]
ON [dbo].[DEVISES_HISTO] ([DEVID], [DVHDATEDEB]);
