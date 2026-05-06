# Projet : Migration FHIR (Clin v2) → Radiant

## Contexte
Migration du modèle de données FHIR (Clin v2) vers le modèle relationnel Radiant pour le projet CQGC (Centre Québécois de Génomique Clinique).

## Utilisateur
Vincent Ferretti — lead technique / architecte du projet. Francophone, expert des deux modèles (FHIR et Radiant). Communiquer en français. Les noms de champs techniques restent en anglais.

## Fichiers locaux
- `fetus.json` — Bundle FHIR exemple prénatal (DYSM, mère + fœtus)
- `nouveau_ne.json` — Bundle FHIR exemple postnatal nouveau-né (POLYM, duo mère-enfant, père manquant)
- `trio-pere-manquant.json` — Bundle FHIR exemple postnatal trio (RGDI, père manquant permanent)
- `init_radiant.sql` — Schéma DDL Radiant consolidé (CREATE statements seulement, extrait des migrations Postgres de `radiant-portal`)
- `~/src/clin-fhir/` — Définition du modèle FHIR (CodeSystems, ValueSets, StructureDefinitions)
- `~/src/radiant-portal/` — Code source Radiant (Go API + React frontend). Schéma authoritatif : `backend/scripts/init-sql/migrations/000001_init.up.sql` (Postgres 14 dans docker-compose)

## Pages Notion
- **Mapping générique (référence)** : https://www.notion.so/33cb0fcecb3d805c9237e3d9c9ca0be2
  - Sections refondues (2026-05-06) avec tableaux 5 colonnes + bloc SQL `// Résumé des changements proposés` + `------` + `// Description de la table finale` :
    - Person + Patient → patient
    - Practitioner + PractitionerRole → Pas d'équivalent dans Radiant
    - ServiceRequest (Analysis) → cases + analysis_catalog + family
    - ClinicalImpression → Pas d'équivalent direct (2 options : table dédiée ou champs sur observations)
  - Sections 2.3 à 2.11 (sequencing, observations, family_history, organization, lab_additional, etc.) **restent au format ancien** à refondre
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

**`analysis_catalog`** :
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

**ClinicalImpression** : 2 options en attente de décision
- Option 1 : créer `clinical_assessment` (id, patient_id, case_id, assessor_id, status_code, assessment_date, age_at_event_days)
- Option 2 : ajouter `assessor_id`, `assessment_date`, `age_at_event_days` directement sur `obs_categorical` / `obs_string` / `family_history`

### Champs FHIR « oubliés » (statut FHIR_ONLY sans action) sur cases
- `note[].authorReference` et `note[].time` : on assume que c'est toujours l'auteur/date de création du case
- `intent` : toujours "order"
- `meta.security` : géré par Ranger / RLS
- `supportingInfo` (refs ClinicalImpression) : voir options ClinicalImpression

## GAPs identifiés (état 2026-05-06)

### Résolus / proposition acceptée
- ✅ `project_id` NOT NULL → `DROP NOT NULL` proposé
- ✅ Code MSSS biomed (55330, 55360, 55372) → champ `analysis_catalog.billing_number` proposé
- ✅ `note[].authorReference` et `note[].time` → assumés = createur/date du case (FHIR_ONLY sans action)
- ✅ Practitioner/PractitionerRole → 3 nouvelles tables proposées

### En cours / en attente de décision
- 🟡 ClinicalImpression : 2 options proposées (table dédiée vs champs sur observations)
- 🟡 Membre de famille manquant : sera représenté par Observation (à définir)
- 🟡 `case_category_code` absent quand postnatal (valeur par défaut à définir)

### Non encore traités
- `Observation.focus` (fœtus) n'a pas d'équivalent dans Radiant
- `RelatedPerson` (RAMQ mère du nouveau-né) n'a pas d'équivalent
- `obs_string` n'a pas de champ `interpretation_code` (CKIN, CNVPG perdent leur interpretation)
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

## État d'avancement (2026-05-06)

### Sections de la page de référence refondues au nouveau format
- ✅ Person + Patient → patient (tableau 5 col + ALTER + CREATE final)
- ✅ Practitioner + PractitionerRole (2 tableaux + 3 CREATE en bloc `javascript`)
- ✅ ServiceRequest (Analysis) → cases + analysis_catalog + family (3 tableaux + 3 blocs SQL)
- ✅ ClinicalImpression → Pas d'équivalent direct (Option 1 refondue)

### Sections restant au format ancien (3 colonnes, à refondre)
- 2.3 ServiceRequest (Sequencing) → sequencing_experiment
- 2.5 Observations → obs_categorical + obs_string (3 sous-tableaux)
- 2.6 FamilyMemberHistory → family_history
- Organization (sans numéro de section)
- 2.9 OrganizationAffiliation
- 2.10 Lab_additional → sample + sequencing_experiment
- 2.11 Roles → Keycloak (texte seul)

### Prochaines étapes possibles
- Trancher entre Option 1 et Option 2 pour ClinicalImpression
- Définir le mécanisme « membre manquant » (Observation à créer)
- Vérifier dans le code Radiant si les nouvelles tables de codes utilisent ou non le suffix `_code`
- Confirmer le nom de la table de codes pour `relationship_to_proband_code` (`family_relationship` existe déjà ; Vincent l'a appelé `relation_to_proband` dans Notion — à clarifier)
- Refondre les sections 2.3 à 2.11 au nouveau format (tableau 5 col + bloc SQL ALTER/CREATE)
- Préparer un script de migration global rassemblant tous les ALTER/CREATE proposés
- Commencer les scripts de migration des données (Phase 2 du plan)
