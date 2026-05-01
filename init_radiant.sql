-- Radiant database schema (CREATE statements only)
-- Extracted from radiant-portal/backend/scripts/init-sql/migrations/

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

CREATE FUNCTION public.tp_history_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    tbl_history TEXT        := FORMAT('%I.%I', TG_TABLE_SCHEMA, TG_TABLE_NAME || '_history');
    next_id     BIGINT      := NEXTVAL(TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || '_history_seq');
    curr_time   TIMESTAMPTZ := NOW();
    deleted_by  TEXT        := NULL;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        deleted_by = current_setting('history.deleted_by', true);
        EXECUTE 'INSERT INTO ' || tbl_history || ' SELECT $1, $2, $3, $4, $5.*'
            USING next_id, curr_time, deleted_by, TG_OP, OLD;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        EXECUTE 'INSERT INTO ' || tbl_history ||
                ' SELECT $1, $2, $3, $4, $5.*' USING next_id, curr_time, deleted_by, TG_OP, NEW;
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        EXECUTE 'INSERT INTO ' || tbl_history ||
                ' SELECT $1, $2, $3, $4, $5.*' USING next_id, curr_time, deleted_by, TG_OP, NEW;
        RETURN NEW;
    END IF;
    RETURN NULL;
    -- Foreign key violation means required related entity doesn't exist anymore.
-- Just skipping trigger invocation
EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN NULL;
END;
$_$;

CREATE TABLE public.affected_status (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.analysis_catalog (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    panel_id integer,
    description text
);

CREATE TABLE public.batch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dry_run boolean DEFAULT false NOT NULL,
    batch_type text NOT NULL,
    status text NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    started_on timestamp without time zone,
    finished_on timestamp without time zone,
    username text NOT NULL,
    payload jsonb NOT NULL,
    summary jsonb,
    report jsonb
);

CREATE TABLE public.case_category (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.case_has_sequencing_experiment (
    case_id integer NOT NULL,
    sequencing_experiment_id integer NOT NULL
);

CREATE TABLE public.cases (
    id integer NOT NULL,
    proband_id integer NOT NULL,
    project_id integer NOT NULL,
    status_code text NOT NULL,
    primary_condition text,
    diagnosis_lab_id integer,
    note text,
    created_on timestamp without time zone NOT NULL,
    updated_on timestamp without time zone NOT NULL,
    analysis_catalog_id integer NOT NULL,
    priority_code text NOT NULL,
    case_type_code text NOT NULL,
    case_category_code text NOT NULL,
    condition_code_system text,
    resolution_status_code text,
    ordering_physician text,
    ordering_organization_id integer,
    submitter_case_id text NOT NULL
);

CREATE TABLE public.case_type (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.consanguinity (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.data_category (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.data_type (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.document (
    id integer NOT NULL,
    name text NOT NULL,
    data_category_code text NOT NULL,
    data_type_code text NOT NULL,
    format_code text NOT NULL,
    size bigint NOT NULL,
    url text NOT NULL,
    hash text,
    created_on timestamp without time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.experimental_strategy (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.family (
    id integer NOT NULL,
    case_id integer NOT NULL,
    family_member_id integer NOT NULL,
    relationship_to_proband_code text NOT NULL,
    affected_status_code text NOT NULL
);

CREATE TABLE public.family_history (
    id integer NOT NULL,
    case_id integer NOT NULL,
    patient_id integer NOT NULL,
    family_member_code text NOT NULL,
    condition text NOT NULL
);

CREATE TABLE public.family_relationship (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.file_format (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.histology_type (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.interpretation_germline (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sequencing_id text NOT NULL,
    locus_id text NOT NULL,
    transcript_id text NOT NULL,
    condition text,
    classification text,
    classification_criterias text,
    transmission_modes text,
    interpretation text,
    pubmed text,
    created_by text,
    created_by_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_by text,
    updated_by_name text,
    updated_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    case_id text
);

CREATE TABLE public.interpretation_germline_history (
    history_id bigint NOT NULL,
    history_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    history_deleted_by character varying,
    history_op character varying NOT NULL,
    id uuid,
    sequencing_id text NOT NULL,
    locus_id text NOT NULL,
    transcript_id text NOT NULL,
    condition text,
    classification text,
    classification_criterias text,
    transmission_modes text,
    interpretation text,
    pubmed text,
    created_by text,
    created_by_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_by text,
    updated_by_name text,
    updated_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    case_id text
);

CREATE SEQUENCE public.interpretation_germline_history_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE public.interpretation_germline_history_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE public.interpretation_somatic (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sequencing_id text NOT NULL,
    locus_id text NOT NULL,
    transcript_id text NOT NULL,
    tumoral_type text,
    oncogenicity text,
    oncogenicity_classification_criterias text,
    clinical_utility text,
    interpretation text,
    pubmed text,
    created_by text,
    created_by_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_by text,
    updated_by_name text,
    updated_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    case_id text
);

CREATE TABLE public.interpretation_somatic_history (
    history_id bigint NOT NULL,
    history_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    history_deleted_by character varying,
    history_op character varying NOT NULL,
    id uuid,
    sequencing_id text NOT NULL,
    locus_id text NOT NULL,
    transcript_id text NOT NULL,
    tumoral_type text,
    oncogenicity text,
    oncogenicity_classification_criterias text,
    clinical_utility text,
    interpretation text,
    pubmed text,
    created_by text,
    created_by_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_by text,
    updated_by_name text,
    updated_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    case_id text
);

CREATE SEQUENCE public.interpretation_somatic_history_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE public.interpretation_somatic_history_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE public.life_status (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.obs_categorical (
    id integer NOT NULL,
    case_id integer NOT NULL,
    patient_id integer NOT NULL,
    observation_code text NOT NULL,
    coding_system text NOT NULL,
    code_value text NOT NULL,
    onset_code text,
    interpretation_code text,
    note text
);

CREATE TABLE public.obs_interpretation (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.obs_string (
    id integer NOT NULL,
    case_id integer NOT NULL,
    patient_id integer NOT NULL,
    observation_code text NOT NULL,
    value text NOT NULL
);

CREATE TABLE public.observation (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.onset (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.organization (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    category_code text NOT NULL
);

CREATE TABLE public.organization_category (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.panel (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    type_code text NOT NULL
);

CREATE TABLE public.panel_has_genes (
    panel_id integer NOT NULL,
    ensembl_id text NOT NULL,
    symbol text NOT NULL
);

CREATE TABLE public.panel_type (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.patient (
    id integer NOT NULL,
    organization_id integer,
    sex_code text NOT NULL,
    date_of_birth date,
    life_status_code text NOT NULL,
    submitter_patient_id text NOT NULL,
    submitter_patient_id_type text NOT NULL,
    first_name text,
    last_name text,
    jhn text
);

CREATE TABLE public.platform (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.priority (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.project (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text
);

CREATE TABLE public.resolution_status (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.sample (
    id integer NOT NULL,
    type_code text NOT NULL,
    parent_sample_id integer,
    tissue_site text,
    histology_code text,
    submitter_sample_id text NOT NULL,
    patient_id integer NOT NULL,
    organization_id integer NOT NULL
);

CREATE TABLE public.sample_type (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.saved_filter (
    user_id text NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    favorite boolean DEFAULT false,
    queries jsonb,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_on timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);

CREATE TABLE public.sequencing_experiment (
    id integer NOT NULL,
    sample_id integer NOT NULL,
    status_code text NOT NULL,
    aliquot text NOT NULL,
    sequencing_lab_id integer,
    run_name text,
    run_alias text,
    run_date timestamp with time zone,
    capture_kit text,
    created_on timestamp without time zone NOT NULL,
    updated_on timestamp without time zone NOT NULL,
    experimental_strategy_code text NOT NULL,
    sequencing_read_technology_code text NOT NULL,
    platform_code text NOT NULL
);

CREATE TABLE public.sequencing_read_technology (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.sex (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.status (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.task (
    id integer NOT NULL,
    task_type_code text NOT NULL,
    created_on timestamp without time zone NOT NULL,
    pipeline_name text,
    pipeline_version text NOT NULL,
    genome_build text
);

CREATE TABLE public.task_context (
    task_id integer NOT NULL,
    case_id integer,
    sequencing_experiment_id integer NOT NULL
);

CREATE TABLE public.task_has_document (
    task_id integer NOT NULL,
    document_id integer NOT NULL,
    type text NOT NULL
);

CREATE TABLE public.task_type (
    code text NOT NULL,
    name_en text NOT NULL
);

CREATE TABLE public.user_preference (
    user_id text NOT NULL,
    content jsonb,
    key text NOT NULL
);

CREATE TABLE public.user_set (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id character varying(255) NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    active boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.user_set_biospecimen (
    user_set_id uuid NOT NULL,
    biospecimen_id character varying(255) NOT NULL
);

CREATE TABLE public.user_set_file (
    user_set_id uuid NOT NULL,
    file_id character varying(255) NOT NULL
);

CREATE TABLE public.user_set_participant (
    user_set_id uuid NOT NULL,
    participant_id character varying(255) NOT NULL
);

CREATE TABLE public.user_set_variant (
    user_set_id uuid NOT NULL,
    variant_id character varying(255) NOT NULL
);

CREATE INDEX idx_case_created_on ON public.cases USING btree (created_on);

CREATE INDEX idx_case_primary_condition ON public.cases USING btree (primary_condition);

CREATE INDEX idx_case_proband_id ON public.cases USING btree (proband_id);

CREATE INDEX idx_case_project_id ON public.cases USING btree (project_id);

CREATE INDEX idx_case_status ON public.cases USING btree (status_code);

CREATE INDEX idx_document_data_type ON public.document USING btree (data_type_code);

CREATE INDEX idx_document_format ON public.document USING btree (format_code);

CREATE INDEX idx_document_name ON public.document USING btree (name);

CREATE INDEX idx_family_case_id ON public.family USING btree (case_id);

CREATE INDEX idx_interpretation_germline_metadata_analysis_id ON public.interpretation_germline USING btree (((metadata ->> 'analysis_id'::text)));

CREATE INDEX idx_interpretation_germline_metadata_patient_id ON public.interpretation_germline USING btree (((metadata ->> 'patient_id'::text)));

CREATE INDEX idx_interpretation_germline_metadata_variant_hash ON public.interpretation_germline USING btree (((metadata ->> 'variant_hash'::text)));

CREATE INDEX idx_interpretation_somatic_metadata_analysis_id ON public.interpretation_somatic USING btree (((metadata ->> 'analysis_id'::text)));

CREATE INDEX idx_interpretation_somatic_metadata_patient_id ON public.interpretation_somatic USING btree (((metadata ->> 'patient_id'::text)));

CREATE INDEX idx_interpretation_somatic_metadata_variant_hash ON public.interpretation_somatic USING btree (((metadata ->> 'variant_hash'::text)));

CREATE INDEX idx_observation_case_id ON public.obs_categorical USING btree (case_id);

CREATE INDEX idx_observation_patient_id ON public.obs_categorical USING btree (patient_id);

CREATE INDEX idx_sample_parent_id ON public.sample USING btree (parent_sample_id);

CREATE INDEX idx_sequencing_experiment_sample_id ON public.sequencing_experiment USING btree (sample_id);

CREATE INDEX idx_task_type ON public.task USING btree (task_type_code);

CREATE TRIGGER trg_interpretation_germline AFTER INSERT OR DELETE OR UPDATE ON public.interpretation_germline FOR EACH ROW EXECUTE FUNCTION public.tp_history_func();

CREATE TRIGGER trg_interpretation_somatic AFTER INSERT OR DELETE OR UPDATE ON public.interpretation_somatic FOR EACH ROW EXECUTE FUNCTION public.tp_history_func();

CREATE UNIQUE INDEX uc_cases_submitter_case_id_filtered
    ON public.cases (project_id, submitter_case_id)
    WHERE (submitter_case_id IS NOT NULL AND submitter_case_id <> '');

CREATE TABLE public.occurrence_note (
    id            uuid         DEFAULT gen_random_uuid() NOT NULL,
    case_id       integer      NOT NULL REFERENCES public.cases(id),
    seq_id        integer      NOT NULL REFERENCES public.sequencing_experiment(id),
    task_id       integer      NOT NULL REFERENCES public.task(id),
    occurrence_id varchar(255) NOT NULL,
    user_id       uuid         NOT NULL,
    user_name     varchar(255) NOT NULL,
    content       text         NOT NULL,
    created_at    timestamp with time zone DEFAULT now() NOT NULL,
    updated_at    timestamp with time zone DEFAULT now() NOT NULL,
    deleted       boolean      DEFAULT false NOT NULL,
    PRIMARY KEY (id)
);

