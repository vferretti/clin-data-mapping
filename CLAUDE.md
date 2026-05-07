# Projet : Migration FHIR (Clin v2) → Radiant

## Contexte
Migration du modèle de données FHIR (Clin v2) vers le modèle relationnel Radiant pour le projet CQGC (Centre Québécois de Génomique Clinique).

## Utilisateur
Vincent Ferretti — lead technique / architecte du projet. Francophone, expert des deux modèles (FHIR et Radiant). Communiquer en français. Les noms de champs techniques restent en anglais.

## Fichiers locaux
- `fetus.json` — Bundle FHIR exemple prénatal (DYSM, mère + fœtus)
- `nouveau_ne.json` — Bundle FHIR exemple postnatal nouveau-né (POLYM, duo mère-enfant, père manquant)
- `trio-pere-manquant.json` — Bundle FHIR exemple postnatal trio (RGDI, père manquant permanent)
- `trio-RGDI-Task.json` — Bundle FHIR avec ServiceRequest (sequencing) + Task (cqgc-analysis-task) + Specimen + DocumentReference (14 docs : VCF, BAM/CRAM, QC, IGV, etc.). Source de référence pour le mapping de la chaîne sequencing → task → document
- `init_radiant.sql` — Schéma DDL Radiant consolidé (CREATE statements seulement, extrait des migrations Postgres de `radiant-portal`)
- `~/src/clin-fhir/` — Définition du modèle FHIR (CodeSystems, ValueSets, StructureDefinitions)
- `~/src/radiant-portal/` — Code source Radiant (Go API + React frontend). Schéma authoritatif : `backend/scripts/init-sql/migrations/000001_init.up.sql` (Postgres 14 dans docker-compose)

## Pages Notion
- **Mapping générique (référence)** : https://www.notion.so/33cb0fcecb3d805c9237e3d9c9ca0be2
  - **Toutes les sections de mapping de tables Radiant sont au nouveau format** (tableau 5 col Champ Radiant | Champ FHIR | Statut | Action | Note + bloc SQL `// Résumé des changements proposés` + `------` + `// Description de la table finale`). État au 2026-05-07 :
    - ✅ Person + Patient → patient
    - ✅ Practitioner + PractitionerRole (3 nouvelles tables)
    - ✅ ServiceRequest (Analysis) → cases + request_catalog + project + family
    - ✅ ClinicalImpression → Option 1 (table `clinical_assessment`) refondue ; Option 2 documentée dans les obs et family_history
    - ✅ Observations → obs_categorical + obs_boolean + obs_string (Option 2)
    - ✅ FamilyMemberHistory → family_history (Option 2)
    - ✅ Organization → organization
    - ✅ ServiceRequest (Sequencing) + Task → sequencing_experiment + case_has_sequencing_experiment
    - ✅ Specimen → sample
    - ✅ Task → task + task_context + task_has_document
    - ✅ DocumentReference → document
  - Sections **callout uniquement** (pas de table ; "Pas d'équivalent") : OrganizationAffiliation, Lab_additional, roles → Keycloak
  - Sections de synthèse (## 3 GAPs, ## 4 Plan, ## 5 Mapping codes) intactes
- **Mapping concret (exemples)** : https://www.notion.so/356b0fcecb3d8064b82cc533b1b44090
  - Fœtus : https://www.notion.so/356b0fcecb3d814bb39fcefaf9148b65
  - Nouveau-né : https://www.notion.so/356b0fcecb3d810fb2a7d8bcd7dd4fa0
  - Trio : https://www.notion.so/356b0fcecb3d81eea3f7d500566c9852
- **Modèle Clin-2** : https://www.notion.so/3eff501252f4456ea887bb56c4072a3e

## Décisions prises (2026-05-04)
1. **Renommage champs patient** : `submitter_patient_id` → `mrn`, `organization_id` → `mrn_organization_id`, **éliminer** `submitter_patient_id_type`
2. **Nouvelle table `clinical_assessment`** proposée (DDL dans la page Mapping principale) pour combler le GAP ClinicalImpression
3. Le champ `intent` FHIR (toujours "order") n'est pas nécessaire dans Radiant

## Décisions prises (2026-05-06)

### Conventions de nommage
- **Suffix `_code`** = FK vers une table de codes Radiant (liste fermée). Ex: `status_code` → `status`, `relationship_to_proband_code` → `family_relationship` (que Vincent appelle aussi `relation_to_proband` dans Notion)
- **Suffix `_number`** pour identifiants externes alphanumériques (pas de FK vers table de codes Radiant). Ex: `license_number` (CMQ), `billing_number` (MSSS)
- **Pas** de `_code` pour `billing_number` (l'ancienne proposition `billing_code` rejetée pour cette raison)

### Format SQL adopté pour la page Notion
Sous chaque tableau de mapping, bloc SQL avec ce patron :
```sql
// Résumé des changements proposés
ALTER TABLE ...
------

// Description de la table finale
CREATE TABLE ...
```

### Modifications de schéma proposées (synthèse)

**`patient`** : renames mrn / mrn_organization_id, drop submitter_patient_id_type (déjà acté 2026-05-04)

**`cases`** :
- `project_id` : DROP NOT NULL (le SR fœtus n'a pas toujours de project)
- `diagnosis_lab_id` → `case_management_org_id` (rename)
- `ordering_organization_id` → `submitter_org_id` (rename)
- `ordering_physician` (text) **DROP**, remplacé par `submitter_id integer` (FK vers `practitioner.id` — pas vers PractitionerRole)
- Nouveaux champs : `primary_condition_note text` (mappé sur Observation INDIC), `order_detail text` (mappé sur orderDetail.text, pour panel reflex)
- **Pas** de `clinical_assessment_id` sur cases (cf. décisions ClinicalImpression ci-dessous)

**`request_catalog`** (renommé depuis `analysis_catalog` le 2026-05-07) :
- `ALTER TABLE public.analysis_catalog RENAME TO request_catalog;` + `cases.analysis_catalog_id` → `cases.request_catalog_id`
- Nouveau champ `billing_number text` (code de facturation MSSS/RAMQ, mappé sur `code.coding[1].code` system `msss.gouv.qc.ca`)

**`family`** :
- Nouveau champ `note text`
- Reste simple : `family_member_id NOT NULL`, `affected_status_code NOT NULL`. Pas de constraint UNIQUE ni CHECK.
- **Membre manquant** : aucune entrée dans `family`. Sera représenté plus tard par une Observation (mécanisme à définir).

**Practitioner / PractitionerRole** (3 tables nouvelles) :
- `practitioner` : id, last_name, first_name, prefix, suffix, license_number, license_organisation_id (FK vers `organization` qui a délivré le permis — typiquement CMQ)
- `practitioner_role` : id, practitioner_id (FK), organization_id (FK), role_code (FK vers `practitioner_role_code`), email
- `practitioner_role_code` : table de codes (code, name_en, name_fr)
- Téléphone abandonné, seul email gardé pour PractitionerRole.telecom
- **Note convention** : Vincent a soulevé que les nouvelles tables de codes Radiant n'ont peut-être plus le suffix `_code` (à vérifier dans le code source). Le DDL propose `practitioner_role_code` — à confirmer.

**ClinicalImpression** : 2 options documentées dans Notion, **pas de tranchage final**. Pour le moment, l'Option 2 a été appliquée concrètement (les 3 champs `assessor_id`, `assessment_date`, `age_at_event_days` ont été ajoutés à `obs_categorical`, `obs_boolean`, `obs_string` ET `family_history`).
- Option 1 : créer `clinical_assessment` (id, patient_id, case_id, assessor_id, status_code, assessment_date, age_at_event_days)
- Option 2 : ajouter `assessor_id`, `assessment_date`, `age_at_event_days` directement sur les 4 tables d'observation

### Tables harmonisées (2026-05-07)
Les 3 tables d'observations partagent maintenant le même squelette de colonnes :
- Communs : `id`, `case_id`, `patient_id`, `observation_code`, `onset_code`, `interpretation_code` (FK vers `obs_interpretation.code`), `note`, `assessor_id`, `assessment_date`, `age_at_event_days`
- Spécifique : `obs_categorical` a `coding_system` + `code_value` ; `obs_boolean` a `value boolean` ; `obs_string` a `value text`
- **Nouvelle table `obs_boolean`** introduite (au lieu de stocker les booléens dans `obs_categorical` avec conversion texte) — vraie colonne Postgres `boolean`

### Tables de la chaîne sequencing → task → document (mappées 2026-05-07)
- `sequencing_experiment` : combine **SR_sequencing** (basedOn, specimen, performer, status) + **Task.extension:sequencing-experiment** (runName, runDate, captureKit, labAliquotId, experimentalStrategy, platform). PAS RADIANT_ONLY comme initialement marqué.
- `case_has_sequencing_experiment` : association case ↔ sequencing_experiment (via SR_sequencing.basedOn)
- `sample` ← `Specimen` : DNA, parent_sample_id, submitter_sample_id (accessionIdentifier.value)
- `task` : Task.code (GEBA), Task.authoredOn, Task.extension:workflow (workflowName "Dragen", workflowVersion "4.4.4", genomeBuild "GRCh38")
- `task_context` : association ternaire task / case (basedOn) / sequencing_experiment (focus)
- `task_has_document` : Task.output[i] (type CHRMR/SNVPG/GCNV/etc., document_id ref)
- `document` ← `DocumentReference` : **1 DocumentReference = N rows** (un par `content[i]` car FHIR groupe fichier principal + index, ex. VCF + TBI ou CRAM + CRAI). `size` est dans une extension custom `full-size.valueDecimal`, pas dans `attachment.size` standard. `hash` et `date` absents des exemples.

### Champs FHIR « oubliés » (statut FHIR_ONLY sans action) sur cases
- `note[].authorReference` et `note[].time` : on assume que c'est toujours l'auteur/date de création du case
- `intent` : toujours "order"
- `meta.security` : géré par Ranger / RLS
- `supportingInfo` (refs ClinicalImpression) : voir options ClinicalImpression

## GAPs identifiés (état 2026-05-07)

### Résolus / proposition acceptée
- ✅ `project_id` NOT NULL → `DROP NOT NULL` proposé
- ✅ Code MSSS biomed (55330, 55360, 55372) → champ `request_catalog.billing_number` proposé
- ✅ `note[].authorReference` et `note[].time` → assumés = createur/date du case (FHIR_ONLY sans action)
- ✅ Practitioner/PractitionerRole → 3 nouvelles tables proposées
- ✅ `obs_string.interpretation_code` ajouté (FK vers `obs_interpretation.code` partagée avec `obs_categorical`)
- ✅ `obs_boolean` créée pour les Observations à `valueBoolean` (pas de conversion en texte)
- ✅ `analysis_catalog` renommé en `request_catalog` (+ rename de la FK `cases.analysis_catalog_id`)
- ✅ Mapping complet de la chaîne sequencing → task → document (sequencing_experiment, case_has_sequencing_experiment, sample, task, task_context, task_has_document, document)

### En cours / en attente de décision
- 🟡 ClinicalImpression : 2 options documentées ; Option 2 appliquée concrètement (champs sur les 4 tables d'obs/family_history) sans choix officiel
- 🟡 Membre de famille manquant : sera représenté par Observation (à définir)
- 🟡 `case_category_code` absent quand postnatal (valeur par défaut à définir)
- 🟡 Question Vincent (notes Notion) : `primary_condition_note`, `primary_condition`, `condition_code_system` pourraient être stockés comme Observation INDIC plutôt qu'en colonnes sur cases — à clarifier
- 🟡 Question Vincent (notes Notion) : `case_type_code` (Germline/Somatic) — à quoi sert-il ? Pipeline ?
- 🟡 Question Vincent (notes Notion) : `orderDetail.text` — autre cas d'usage que le panel reflex ?

### Non encore traités
- `Observation.focus` (fœtus) n'a pas d'équivalent dans Radiant
- `RelatedPerson` (RAMQ mère du nouveau-né) n'a pas d'équivalent
- DDM et âge gestationnel : codes LOINC + types DateTime/Quantity ne rentrent pas dans obs_categorical/obs_string
- Lien mère↔fœtus (`Patient.link.type=seealso`) n'a pas d'équivalent
- `OrganizationAffiliation` (routing labo↔hôpital par spécialité) n'a pas de table

## Préférences de format
- Tableaux de mapping Notion avec colonnes colorées : vert (OK), orange (Partiel), rouge (GAP), jaune (Radiant only)
- Écrire directement dans les pages Notion (pas juste proposer le contenu en texte)

## Architecture Auth : Keycloak + Ranger (discussion 2026-05-05)

### Contexte
FHIR utilise `Practitioner`, `PractitionerRole` et `Organization` pour modéliser les professionnels. Radiant utilisera **Keycloak** (authentification) + **Apache Ranger** (rôles et accès). La question : peut-on abandonner complètement les concepts FHIR Practitioner/PractitionerRole ?

### Conclusion : approche hybride recommandée

**Keycloak/Ranger** gèrent l'auth et les rôles, mais il faut une **table `practitioner` légère** dans Radiant pour gérer le cas des prescripteurs sans compte applicatif (médecins externes qui prescrivent mais n'utilisent pas l'app).

### 3 niveaux d'identité

| Concept | Stockage | Exemple |
|---|---|---|
| Utilisateur actif (se connecte) | Keycloak + Ranger | Généticien qui utilise l'app |
| Prescripteur connu (ne se connecte pas) | Table `practitioner` dans Radiant | Médecin externe qui prescrit |
| Snapshot sur la prescription | Champs dénormalisés dans `cases` | `requester_name`, `requester_licence` pour audit |

### DDL proposé pour `practitioner`

```sql
CREATE TABLE public.practitioner (
    id integer NOT NULL,
    licence_number text,          -- numéro de permis CMQ
    licence_organization text,    -- 'CMQ', 'OPQ', etc.
    first_name text NOT NULL,
    last_name text NOT NULL,
    keycloak_user_id uuid,        -- NULL si pas de compte
    is_active boolean NOT NULL DEFAULT true,
    created_on timestamp without time zone NOT NULL,
    updated_on timestamp without time zone NOT NULL
);
```

- `keycloak_user_id` non NULL → utilisateur avec compte, rôles/accès via Keycloak/Ranger
- `keycloak_user_id` NULL → prescripteur externe, identifié par permis + nom
- `cases.requester_id` → FK vers `practitioner` (au lieu d'un keycloak_user_id direct)

### Pourquoi une table plutôt que juste des champs sur `cases`
- Un même prescripteur externe peut prescrire plusieurs analyses → lien cohérent
- Si le prescripteur obtient un compte, mise à jour d'un seul enregistrement
- Recherches par prescripteur = `WHERE requester_id = ?` au lieu de `LIKE` sur texte

### Points Keycloak/Ranger pertinents
- Keycloak supporte nativement `enabled` (booléen) pour activer/désactiver un utilisateur
- Un utilisateur désactivé ne peut plus se connecter mais son identité reste dans le système
- Ranger gère les politiques d'accès aux données (row-level, column-level)
- Pas besoin de recréer le modèle FHIR PractitionerRole — Ranger couvre les rôles

### Décision : en attente de validation par Vincent

## État d'avancement (2026-05-07)

### Toutes les sections de mapping de tables Radiant sont au nouveau format
La page Notion de référence est désormais **entièrement refondue** au format 5 colonnes (Champ Radiant | Champ FHIR | Statut | Action | Note) avec bloc SQL ALTER/CREATE :

- ✅ Person + Patient → patient
- ✅ Practitioner + PractitionerRole (3 tables nouvelles)
- ✅ ServiceRequest (Analysis) → cases + request_catalog + project + family
- ✅ ClinicalImpression → clinical_assessment (Option 1 — Option 2 aussi appliquée)
- ✅ Observations → obs_categorical + obs_boolean (NEW) + obs_string
- ✅ FamilyMemberHistory → family_history
- ✅ Organization → organization
- ✅ ServiceRequest (Sequencing) + Task → sequencing_experiment + case_has_sequencing_experiment
- ✅ Specimen → sample
- ✅ Task → task + task_context + task_has_document
- ✅ DocumentReference → document
- (callout uniquement) OrganizationAffiliation, Lab_additional, roles → Keycloak

### Prochaines étapes possibles
- Trancher officiellement entre Option 1 et Option 2 pour ClinicalImpression (Option 2 est appliquée de facto dans Notion)
- Définir le mécanisme « membre manquant » (Observation à créer)
- Vérifier dans le code Radiant si les nouvelles tables de codes utilisent ou non le suffix `_code`
- Confirmer le nom de la table de codes pour `relationship_to_proband_code` (`family_relationship` existe déjà ; Vincent l'a appelé `relation_to_proband` dans Notion — à clarifier)
- Répondre aux questions de Vincent restées dans les notes Notion (case_type_code, orderDetail, primary_condition*)
- Préparer un script de migration global rassemblant tous les ALTER/CREATE proposés
- Commencer les scripts de migration des données (Phase 2 du plan)
- Aborder les GAPs non encore traités (Observation.focus, RelatedPerson, DDM/âge gestationnel, lien mère↔fœtus, OrganizationAffiliation)
