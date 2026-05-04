# Projet : Migration FHIR (Clin v2) → Radiant

## Contexte
Migration du modèle de données FHIR (Clin v2) vers le modèle relationnel Radiant pour le projet CQGC (Centre Québécois de Génomique Clinique).

## Utilisateur
Vincent Ferretti — lead technique / architecte du projet. Francophone, expert des deux modèles (FHIR et Radiant). Communiquer en français. Les noms de champs techniques restent en anglais.

## Fichiers locaux
- `fetus.json` — Bundle FHIR exemple prénatal (DYSM, mère + fœtus)
- `nouveau_ne.json` — Bundle FHIR exemple postnatal nouveau-né (POLYM, duo mère-enfant, père manquant)
- `trio-pere-manquant.json` — Bundle FHIR exemple postnatal trio (RGDI, père manquant permanent)
- `init_radiant.sql` — Schéma DDL complet de la base Radiant
- `~/src/clin-fhir/` — Définition du modèle FHIR (CodeSystems, ValueSets, StructureDefinitions)

## Pages Notion
- **Mapping générique (référence)** : https://www.notion.so/33cb0fcecb3d805c9237e3d9c9ca0be2
  - Section 2.1 (Person+Patient → patient) révisée, considérée bonne
  - Section 2.2 (ServiceRequest → cases) complétée avec tableau révisé (2026-05-04)
- **Mapping concret (exemples)** : https://www.notion.so/356b0fcecb3d8064b82cc533b1b44090
  - Fœtus : https://www.notion.so/356b0fcecb3d814bb39fcefaf9148b65
  - Nouveau-né : https://www.notion.so/356b0fcecb3d810fb2a7d8bcd7dd4fa0
  - Trio : https://www.notion.so/356b0fcecb3d81eea3f7d500566c9852
- **Modèle Clin-2** : https://www.notion.so/3eff501252f4456ea887bb56c4072a3e

## Décisions prises (2026-05-04)
1. **Renommage champs patient** : `submitter_patient_id` → `mrn`, `organization_id` → `mrn_organization_id`, **éliminer** `submitter_patient_id_type`
2. **Nouvelle table `clinical_assessment`** proposée (DDL dans la page Mapping principale) pour combler le GAP ClinicalImpression
3. Le champ `intent` FHIR (toujours "order") n'est pas nécessaire dans Radiant

## GAPs majeurs identifiés
- `project_id` NOT NULL dans Radiant mais absent du SR FHIR dans le cas fœtus
- `Observation.focus` (fœtus) n'a pas d'équivalent dans Radiant
- `RelatedPerson` (RAMQ mère du nouveau-né) n'a pas d'équivalent
- `obs_string` n'a pas de champ `interpretation_code` (CKIN, CNVPG perdent leur interpretation)
- `case_category_code` absent quand postnatal (valeur par défaut à définir)
- DDM et âge gestationnel : codes LOINC + types DateTime/Quantity ne rentrent pas dans obs_categorical/obs_string
- `note[].authorReference` et `note[].time` sont perdus
- Code MSSS biomed (55330, 55360, 55372) n'a pas de champ Radiant
- `affected_status_code` dans table `family` doit être déduit de l'observation DSTA du membre
- Lien mère↔fœtus (`Patient.link.type=seealso`) n'a pas d'équivalent

## Préférences de format
- Tableaux de mapping Notion avec colonnes colorées : vert (OK), orange (Partiel), rouge (GAP), jaune (Radiant only)
- Écrire directement dans les pages Notion (pas juste proposer le contenu en texte)

## État d'avancement (2026-05-04)
- Page de référence : sections 2.1 et 2.2 révisées, sections 2.3+ restent à réviser
- Page de mapping concret : 3 pages enfant créées avec mapping détaillé complet
- Prochaines étapes possibles :
  - Réviser les sections 2.3 à 2.11 de la page de référence
  - Proposer des solutions concrètes pour les GAPs
  - Travailler sur le DDL des modifications du schéma Radiant
  - Commencer les scripts de migration
