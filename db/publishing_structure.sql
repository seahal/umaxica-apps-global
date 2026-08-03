SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: publishing_assert_version_snapshot_complete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_assert_version_snapshot_complete() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ DECLARE target_version_id bigint; source_revision_id bigint; mismatch integer; BEGIN IF TG_TABLE_NAME = 'publishing_entry_versions' THEN target_version_id := NEW.id; ELSE target_version_id := NEW.entry_version_id; END IF; SELECT entry_revision_id INTO source_revision_id FROM public.publishing_entry_versions WHERE id = target_version_id; IF source_revision_id IS NULL THEN RETURN NULL; END IF; SELECT count(*) INTO mismatch FROM ( ( SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_revision_single_taxonomy_assignments WHERE entry_revision_id = source_revision_id EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_version_single_taxonomy_assignments WHERE entry_version_id = target_version_id ) UNION ALL ( SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_version_single_taxonomy_assignments WHERE entry_version_id = target_version_id EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id FROM public.publishing_revision_single_taxonomy_assignments WHERE entry_revision_id = source_revision_id ) ) AS single_difference; IF mismatch > 0 THEN RAISE EXCEPTION 'publishing taxonomy: version % single-valued snapshots do not match revision %', target_version_id, source_revision_id USING ERRCODE = 'integrity_constraint_violation'; END IF; SELECT count(*) INTO mismatch FROM ( ( SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_revision_multiple_taxonomy_assignments WHERE entry_revision_id = source_revision_id EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_version_multiple_taxonomy_assignments WHERE entry_version_id = target_version_id ) UNION ALL ( SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_version_multiple_taxonomy_assignments WHERE entry_version_id = target_version_id EXCEPT ALL SELECT vocabulary_id, taxonomy_term_id, position FROM public.publishing_revision_multiple_taxonomy_assignments WHERE entry_revision_id = source_revision_id ) ) AS multiple_difference; IF mismatch > 0 THEN RAISE EXCEPTION 'publishing taxonomy: version % ordered snapshots do not match revision %', target_version_id, source_revision_id USING ERRCODE = 'integrity_constraint_violation'; END IF; RETURN NULL; END; $$;


--
-- Name: publishing_promoted_revision_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_promoted_revision_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ DECLARE subject_revision_id bigint; promoted_version_id bigint; BEGIN IF TG_TABLE_NAME = 'publishing_entry_revisions' THEN IF TG_OP = 'DELETE' THEN subject_revision_id := OLD.id; ELSE subject_revision_id := NEW.id; END IF; ELSIF TG_OP = 'DELETE' THEN subject_revision_id := OLD.entry_revision_id; ELSE subject_revision_id := NEW.entry_revision_id; END IF; SELECT id INTO promoted_version_id FROM public.publishing_entry_versions WHERE entry_revision_id = subject_revision_id; IF promoted_version_id IS NOT NULL THEN RAISE EXCEPTION 'publishing: revision % was promoted into version % and can no longer change (attempted % on %)', subject_revision_id, promoted_version_id, TG_OP, TG_TABLE_NAME USING ERRCODE = 'restrict_violation'; END IF; IF TG_OP = 'DELETE' THEN RETURN OLD; END IF; RETURN NEW; END; $$;


--
-- Name: publishing_reject_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_reject_mutation() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ BEGIN RAISE EXCEPTION 'publishing: % is immutable (attempted %)', TG_TABLE_NAME, TG_OP; END; $$;


--
-- Name: publishing_reject_retirement_by_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_reject_retirement_by_deletion() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ BEGIN RAISE EXCEPTION 'publishing taxonomy: % rows are retired by archiving, never deleted (id %)', TG_TABLE_NAME, OLD.id USING ERRCODE = 'restrict_violation'; END; $$;


--
-- Name: publishing_taxonomy_assignment_scope_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_taxonomy_assignment_scope_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $_$ DECLARE owner_table text := TG_ARGV[0]; owner_column text := TG_ARGV[1]; owner_id bigint; vocabulary_audience text; vocabulary_surface text; edition_audience text; edition_surface text; BEGIN EXECUTE format('SELECT ($1).%I', owner_column) INTO owner_id USING NEW; SELECT v.audience, v.surface INTO vocabulary_audience, vocabulary_surface FROM public.publishing_vocabularies v WHERE v.id = NEW.vocabulary_id; EXECUTE format( 'SELECT ed.audience, ed.surface FROM public.%I o JOIN public.publishing_entries en ON en.id = o.entry_id JOIN public.publishing_editions ed ON ed.id = en.edition_id WHERE o.id = $1', owner_table) INTO edition_audience, edition_surface USING owner_id; IF vocabulary_audience IS DISTINCT FROM edition_audience OR vocabulary_surface IS DISTINCT FROM edition_surface THEN RAISE EXCEPTION 'publishing taxonomy: vocabulary scope %/% does not match edition scope %/%', vocabulary_audience, vocabulary_surface, edition_audience, edition_surface; END IF; RETURN NEW; END; $_$;


--
-- Name: publishing_taxonomy_term_hierarchy_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_taxonomy_term_hierarchy_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ DECLARE parent_depth integer; BEGIN IF NEW.parent_id IS NULL THEN RETURN NEW; END IF; SELECT depth INTO parent_depth FROM public.publishing_taxonomy_terms WHERE id = NEW.parent_id; IF parent_depth IS NULL THEN RAISE EXCEPTION 'publishing taxonomy: parent term % not found', NEW.parent_id; END IF; IF NEW.depth <> parent_depth + 1 THEN RAISE EXCEPTION 'publishing taxonomy: depth % must equal parent depth % plus one', NEW.depth, parent_depth; END IF; IF EXISTS ( WITH RECURSIVE ancestors(id, parent_id, level) AS ( SELECT t.id, t.parent_id, 1 FROM public.publishing_taxonomy_terms t WHERE t.id = NEW.parent_id UNION ALL SELECT t.id, t.parent_id, a.level + 1 FROM public.publishing_taxonomy_terms t JOIN ancestors a ON t.id = a.parent_id WHERE a.level <= 8 + 1 ) SELECT 1 FROM ancestors WHERE id = NEW.id ) THEN RAISE EXCEPTION 'publishing taxonomy: term % cannot descend from itself', NEW.id; END IF; RETURN NEW; END; $$;


--
-- Name: publishing_taxonomy_term_path(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_taxonomy_term_path(target_id bigint) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog', 'public'
    AS $$ WITH RECURSIVE chain(id, parent_id, public_id, slug, name, level) AS ( SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, 0 FROM public.publishing_taxonomy_terms t WHERE t.id = target_id UNION ALL SELECT t.id, t.parent_id, t.public_id, t.slug, t.name, c.level + 1 FROM public.publishing_taxonomy_terms t JOIN chain c ON t.id = c.parent_id ) SELECT coalesce( jsonb_agg(jsonb_build_object('public_id', public_id, 'slug', slug, 'name', name) ORDER BY level DESC), '[]'::jsonb ) FROM chain; $$;


--
-- Name: publishing_valid_term_path(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_valid_term_path(path jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'pg_catalog', 'public'
    AS $$ SELECT jsonb_typeof(path) = 'array' AND NOT EXISTS ( SELECT 1 FROM jsonb_array_elements(path) AS element(value) WHERE jsonb_typeof(element.value) <> 'object' OR jsonb_typeof(element.value -> 'public_id') IS DISTINCT FROM 'string' OR jsonb_typeof(element.value -> 'slug') IS DISTINCT FROM 'string' OR jsonb_typeof(element.value -> 'name') IS DISTINCT FROM 'string' OR (SELECT count(*) FROM jsonb_object_keys(element.value)) <> 3 ); $$;


--
-- Name: publishing_version_multiple_taxonomy_assignments_snapshot(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_version_multiple_taxonomy_assignments_snapshot() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ DECLARE vocabulary public.publishing_vocabularies%ROWTYPE; term public.publishing_taxonomy_terms%ROWTYPE; BEGIN SELECT * INTO vocabulary FROM public.publishing_vocabularies WHERE id = NEW.vocabulary_id; SELECT * INTO term FROM public.publishing_taxonomy_terms WHERE id = NEW.taxonomy_term_id; IF vocabulary.id IS NULL OR term.id IS NULL THEN RAISE EXCEPTION 'publishing taxonomy: cannot snapshot a missing vocabulary or term' USING ERRCODE = 'foreign_key_violation'; END IF; NEW.vocabulary_public_id_snapshot := vocabulary.public_id; NEW.vocabulary_key_snapshot := vocabulary.key; NEW.vocabulary_kind_snapshot := vocabulary.kind; NEW.term_public_id_snapshot := term.public_id; NEW.term_slug_snapshot := term.slug; NEW.term_name_snapshot := term.name; NEW.term_path_snapshot := publishing_taxonomy_term_path(term.id); NEW.locale_snapshot := term.locale; NEW.position_snapshot := NEW.position; RETURN NEW; END; $$;


--
-- Name: publishing_version_single_taxonomy_assignments_snapshot(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_version_single_taxonomy_assignments_snapshot() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ DECLARE vocabulary public.publishing_vocabularies%ROWTYPE; term public.publishing_taxonomy_terms%ROWTYPE; BEGIN SELECT * INTO vocabulary FROM public.publishing_vocabularies WHERE id = NEW.vocabulary_id; SELECT * INTO term FROM public.publishing_taxonomy_terms WHERE id = NEW.taxonomy_term_id; IF vocabulary.id IS NULL OR term.id IS NULL THEN RAISE EXCEPTION 'publishing taxonomy: cannot snapshot a missing vocabulary or term' USING ERRCODE = 'foreign_key_violation'; END IF; NEW.vocabulary_public_id_snapshot := vocabulary.public_id; NEW.vocabulary_key_snapshot := vocabulary.key; NEW.vocabulary_kind_snapshot := vocabulary.kind; NEW.term_public_id_snapshot := term.public_id; NEW.term_slug_snapshot := term.slug; NEW.term_name_snapshot := term.name; NEW.term_path_snapshot := publishing_taxonomy_term_path(term.id); NEW.locale_snapshot := term.locale; RETURN NEW; END; $$;


--
-- Name: publishing_vocabulary_structure_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publishing_vocabulary_structure_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public'
    AS $$ BEGIN IF NEW.public_id IS DISTINCT FROM OLD.public_id OR NEW.audience IS DISTINCT FROM OLD.audience OR NEW.surface IS DISTINCT FROM OLD.surface OR NEW.key IS DISTINCT FROM OLD.key OR NEW.kind IS DISTINCT FROM OLD.kind THEN IF EXISTS (SELECT 1 FROM public.publishing_taxonomy_terms t WHERE t.vocabulary_id = OLD.id) THEN RAISE EXCEPTION 'publishing taxonomy: vocabulary % has terms; public_id, audience, surface, key, and kind are frozen', OLD.id USING ERRCODE = 'restrict_violation'; END IF; END IF; RETURN NEW; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: publishing_editions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_editions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    audience character varying NOT NULL,
    surface character varying NOT NULL,
    locale character varying NOT NULL,
    region_code character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_editions_audience CHECK (((audience)::text = ANY ((ARRAY['app'::character varying, 'com'::character varying, 'org'::character varying])::text[]))),
    CONSTRAINT chk_publishing_editions_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_editions_region CHECK (((((surface)::text = 'info'::text) AND (region_code IS NULL)) OR (((surface)::text = ANY ((ARRAY['docs'::character varying, 'news'::character varying, 'help'::character varying])::text[])) AND (region_code IS NOT NULL) AND ((region_code)::text ~ '^[a-z]{2}$'::text)))),
    CONSTRAINT chk_publishing_editions_surface CHECK (((surface)::text = ANY ((ARRAY['info'::character varying, 'docs'::character varying, 'news'::character varying, 'help'::character varying])::text[])))
);


--
-- Name: publishing_editions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_editions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_editions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_editions_id_seq OWNED BY public.publishing_editions.id;


--
-- Name: publishing_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_entries (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    edition_id bigint NOT NULL,
    locale character varying NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    current_revision_id bigint,
    CONSTRAINT chk_publishing_entries_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_publishing_entries_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT chk_publishing_entries_public_id CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_entries_id_seq OWNED BY public.publishing_entries.id;


--
-- Name: publishing_entry_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_entry_revisions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    restored_from_revision_id bigint,
    restored_from_version_id bigint,
    locale character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    body jsonb NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_entry_revisions_body CHECK ((jsonb_typeof(body) = 'object'::text)),
    CONSTRAINT chk_publishing_entry_revisions_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_publishing_entry_revisions_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_entry_revisions_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_publishing_restore_source CHECK ((num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1)),
    CONSTRAINT chk_publishing_revision_sequence CHECK ((sequence > 0))
);


--
-- Name: publishing_entry_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_entry_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_entry_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_entry_revisions_id_seq OWNED BY public.publishing_entry_revisions.id;


--
-- Name: publishing_entry_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_entry_slugs (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    edition_id bigint NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    state character varying NOT NULL,
    canonicalized_at timestamp(6) with time zone,
    redirected_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_entry_slugs_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_slug_format CHECK (((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)),
    CONSTRAINT chk_publishing_slug_state CHECK (((state)::text = ANY ((ARRAY['reserved'::character varying, 'canonical'::character varying, 'redirect'::character varying])::text[]))),
    CONSTRAINT chk_publishing_slug_timestamps CHECK (((((state)::text = 'reserved'::text) AND (canonicalized_at IS NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'canonical'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NULL)) OR (((state)::text = 'redirect'::text) AND (canonicalized_at IS NOT NULL) AND (redirected_at IS NOT NULL) AND (redirected_at >= canonicalized_at))))
);


--
-- Name: publishing_entry_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_entry_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_entry_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_entry_slugs_id_seq OWNED BY public.publishing_entry_slugs.id;


--
-- Name: publishing_entry_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_entry_versions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    locale character varying NOT NULL,
    title character varying NOT NULL,
    summary text,
    body jsonb NOT NULL,
    schema_version integer NOT NULL,
    content_digest character varying(64) NOT NULL,
    created_by_operator_public_id character varying(21),
    sequence integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_entry_versions_body CHECK ((jsonb_typeof(body) = 'object'::text)),
    CONSTRAINT chk_publishing_entry_versions_digest CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT chk_publishing_entry_versions_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_entry_versions_schema CHECK ((schema_version > 0)),
    CONSTRAINT chk_publishing_version_sequence CHECK ((sequence > 0))
);


--
-- Name: publishing_entry_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_entry_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_entry_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_entry_versions_id_seq OWNED BY public.publishing_entry_versions.id;


--
-- Name: publishing_media_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_media_files (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    storage_key character varying NOT NULL,
    content_type character varying NOT NULL,
    byte_size bigint NOT NULL,
    digest_algorithm character varying NOT NULL,
    digest character varying NOT NULL,
    width integer,
    height integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    purged_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_media_digest CHECK ((((digest_algorithm)::text = 'sha256'::text) AND ((digest)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT chk_publishing_media_dimensions CHECK ((((width IS NULL) AND (height IS NULL)) OR ((width > 0) AND (height > 0)))),
    CONSTRAINT chk_publishing_media_files_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_publishing_media_files_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_media_metadata CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT chk_publishing_media_size CHECK ((byte_size >= 0))
);


--
-- Name: publishing_media_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_media_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_media_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_media_files_id_seq OWNED BY public.publishing_media_files.id;


--
-- Name: publishing_media_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_media_usages (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    media_file_id bigint NOT NULL,
    entry_id bigint NOT NULL,
    entry_revision_id bigint,
    entry_version_id bigint,
    locale character varying NOT NULL,
    role character varying NOT NULL,
    field_path character varying,
    block_path character varying,
    "position" integer DEFAULT 0 NOT NULL,
    alt_text character varying,
    caption text,
    presentation_metadata jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_media_owner_xor CHECK ((num_nonnulls(entry_revision_id, entry_version_id) = 1)),
    CONSTRAINT chk_publishing_media_path CHECK (((field_path IS NOT NULL) OR (block_path IS NOT NULL))),
    CONSTRAINT chk_publishing_media_position CHECK (("position" >= 0)),
    CONSTRAINT chk_publishing_media_usages_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_presentation_metadata CHECK (((presentation_metadata IS NULL) OR (jsonb_typeof(presentation_metadata) = 'object'::text)))
);


--
-- Name: publishing_media_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_media_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_media_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_media_usages_id_seq OWNED BY public.publishing_media_usages.id;


--
-- Name: publishing_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_publications (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    entry_id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    effective_from timestamp(6) with time zone NOT NULL,
    effective_until timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    cancellation_reason character varying,
    terminated_at timestamp(6) with time zone,
    termination_reason character varying,
    created_by_operator_public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_publication_cancellation CHECK ((((cancelled_at IS NULL) AND (cancellation_reason IS NULL)) OR ((cancelled_at IS NOT NULL) AND (cancellation_reason IS NOT NULL) AND (cancelled_at < effective_from)))),
    CONSTRAINT chk_publishing_publication_end_mode CHECK ((NOT ((cancelled_at IS NOT NULL) AND (terminated_at IS NOT NULL)))),
    CONSTRAINT chk_publishing_publication_termination CHECK ((((terminated_at IS NULL) AND (termination_reason IS NULL)) OR ((terminated_at IS NOT NULL) AND (termination_reason IS NOT NULL) AND (terminated_at >= effective_from) AND (effective_until = terminated_at)))),
    CONSTRAINT chk_publishing_publication_window CHECK (((effective_until IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT chk_publishing_publications_public_id CHECK ((char_length((public_id)::text) = 21))
);


--
-- Name: publishing_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_publications_id_seq OWNED BY public.publishing_publications.id;


--
-- Name: publishing_revision_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_revision_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_revision_multiple_taxonomy_assignments_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_publishing_revision_multiple_taxonomy_assignments_position CHECK (("position" >= 0))
);


--
-- Name: publishing_revision_multiple_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_revision_multiple_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_revision_multiple_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_revision_multiple_taxonomy_assignments_id_seq OWNED BY public.publishing_revision_multiple_taxonomy_assignments.id;


--
-- Name: publishing_revision_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_revision_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_revision_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_revision_single_taxonomy_assignments_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text))
);


--
-- Name: publishing_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_revision_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_revision_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_revision_single_taxonomy_assignments_id_seq OWNED BY public.publishing_revision_single_taxonomy_assignments.id;


--
-- Name: publishing_taxonomy_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_taxonomy_terms (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    locale character varying NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_taxonomy_terms_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_publishing_taxonomy_terms_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_terms_depth CHECK (((depth >= 0) AND (depth <= 8))),
    CONSTRAINT chk_publishing_terms_flat_has_no_parent CHECK ((((vocabulary_kind)::text <> 'multiple_ordered_flat'::text) OR ((parent_id IS NULL) AND (depth = 0)))),
    CONSTRAINT chk_publishing_terms_kind CHECK (((vocabulary_kind)::text = ANY ((ARRAY['single_hierarchical'::character varying, 'multiple_ordered_flat'::character varying])::text[]))),
    CONSTRAINT chk_publishing_terms_locale CHECK (((locale)::text = ANY ((ARRAY['ja'::character varying, 'en'::character varying])::text[]))),
    CONSTRAINT chk_publishing_terms_name CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT chk_publishing_terms_not_self_parent CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT chk_publishing_terms_position CHECK (("position" >= 0)),
    CONSTRAINT chk_publishing_terms_root_depth CHECK ((((parent_id IS NULL) AND (depth = 0)) OR ((parent_id IS NOT NULL) AND (depth > 0)))),
    CONSTRAINT chk_publishing_terms_slug CHECK (((btrim((slug)::text) <> ''::text) AND ((slug)::text ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'::text)))
);


--
-- Name: publishing_taxonomy_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_taxonomy_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_taxonomy_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_taxonomy_terms_id_seq OWNED BY public.publishing_taxonomy_terms.id;


--
-- Name: publishing_version_multiple_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_version_multiple_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    "position" integer NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    position_snapshot integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_kind CHECK (((vocabulary_kind)::text = 'multiple_ordered_flat'::text)),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_kind_snaps CHECK (((vocabulary_kind_snapshot)::text = ANY ((ARRAY['single_hierarchical'::character varying, 'multiple_ordered_flat'::character varying])::text[]))),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_locale_sna CHECK (((locale_snapshot)::text = ANY ((ARRAY['ja'::character varying, 'en'::character varying])::text[]))),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_path_snaps CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_position CHECK ((("position" >= 0) AND (position_snapshot >= 0))),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_snapshot_p CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_term_publi CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_publishing_version_multiple_taxonomy_assignments_vocab_publ CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_version_multiple_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_version_multiple_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_version_multiple_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_version_multiple_taxonomy_assignments_id_seq OWNED BY public.publishing_version_multiple_taxonomy_assignments.id;


--
-- Name: publishing_version_single_taxonomy_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_version_single_taxonomy_assignments (
    id bigint NOT NULL,
    entry_version_id bigint NOT NULL,
    vocabulary_id bigint NOT NULL,
    vocabulary_kind character varying NOT NULL,
    taxonomy_term_id bigint NOT NULL,
    locale character varying NOT NULL,
    vocabulary_public_id_snapshot character varying(21) NOT NULL,
    vocabulary_key_snapshot character varying NOT NULL,
    vocabulary_kind_snapshot character varying NOT NULL,
    term_public_id_snapshot character varying(21) NOT NULL,
    term_slug_snapshot character varying NOT NULL,
    term_name_snapshot character varying NOT NULL,
    term_path_snapshot jsonb NOT NULL,
    locale_snapshot character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_kind CHECK (((vocabulary_kind)::text = 'single_hierarchical'::text)),
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_kind_snapsho CHECK (((vocabulary_kind_snapshot)::text = ANY ((ARRAY['single_hierarchical'::character varying, 'multiple_ordered_flat'::character varying])::text[]))),
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_locale_snaps CHECK (((locale_snapshot)::text = ANY ((ARRAY['ja'::character varying, 'en'::character varying])::text[]))),
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_path_snapsho CHECK (public.publishing_valid_term_path(term_path_snapshot)),
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_snapshot_pre CHECK (((btrim((vocabulary_key_snapshot)::text) <> ''::text) AND (btrim((term_slug_snapshot)::text) <> ''::text) AND (btrim((term_name_snapshot)::text) <> ''::text))),
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_term_public_ CHECK ((char_length((term_public_id_snapshot)::text) = 21)),
    CONSTRAINT chk_publishing_version_single_taxonomy_assignments_vocab_public CHECK ((char_length((vocabulary_public_id_snapshot)::text) = 21))
);


--
-- Name: publishing_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_version_single_taxonomy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_version_single_taxonomy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_version_single_taxonomy_assignments_id_seq OWNED BY public.publishing_version_single_taxonomy_assignments.id;


--
-- Name: publishing_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publishing_vocabularies (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    audience character varying NOT NULL,
    surface character varying NOT NULL,
    key character varying NOT NULL,
    kind character varying NOT NULL,
    internal_name character varying NOT NULL,
    description text,
    archived_at timestamp(6) with time zone,
    archive_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_publishing_vocabularies_archive CHECK ((((archived_at IS NULL) AND (archive_reason IS NULL)) OR ((archived_at IS NOT NULL) AND (archive_reason IS NOT NULL)))),
    CONSTRAINT chk_publishing_vocabularies_audience CHECK (((audience)::text = ANY ((ARRAY['app'::character varying, 'com'::character varying, 'org'::character varying])::text[]))),
    CONSTRAINT chk_publishing_vocabularies_internal_name CHECK ((btrim((internal_name)::text) <> ''::text)),
    CONSTRAINT chk_publishing_vocabularies_key CHECK (((btrim((key)::text) <> ''::text) AND ((key)::text ~ '^[a-z][a-z0-9_]*$'::text))),
    CONSTRAINT chk_publishing_vocabularies_kind CHECK (((kind)::text = ANY ((ARRAY['single_hierarchical'::character varying, 'multiple_ordered_flat'::character varying])::text[]))),
    CONSTRAINT chk_publishing_vocabularies_public_id CHECK ((char_length((public_id)::text) = 21)),
    CONSTRAINT chk_publishing_vocabularies_surface CHECK (((surface)::text = ANY ((ARRAY['info'::character varying, 'docs'::character varying, 'news'::character varying, 'help'::character varying])::text[])))
);


--
-- Name: publishing_vocabularies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publishing_vocabularies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publishing_vocabularies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publishing_vocabularies_id_seq OWNED BY public.publishing_vocabularies.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: publishing_editions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_editions ALTER COLUMN id SET DEFAULT nextval('public.publishing_editions_id_seq'::regclass);


--
-- Name: publishing_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entries ALTER COLUMN id SET DEFAULT nextval('public.publishing_entries_id_seq'::regclass);


--
-- Name: publishing_entry_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_revisions ALTER COLUMN id SET DEFAULT nextval('public.publishing_entry_revisions_id_seq'::regclass);


--
-- Name: publishing_entry_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_slugs ALTER COLUMN id SET DEFAULT nextval('public.publishing_entry_slugs_id_seq'::regclass);


--
-- Name: publishing_entry_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions ALTER COLUMN id SET DEFAULT nextval('public.publishing_entry_versions_id_seq'::regclass);


--
-- Name: publishing_media_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_files ALTER COLUMN id SET DEFAULT nextval('public.publishing_media_files_id_seq'::regclass);


--
-- Name: publishing_media_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_usages ALTER COLUMN id SET DEFAULT nextval('public.publishing_media_usages_id_seq'::regclass);


--
-- Name: publishing_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_publications ALTER COLUMN id SET DEFAULT nextval('public.publishing_publications_id_seq'::regclass);


--
-- Name: publishing_revision_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_revision_multiple_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_revision_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_revision_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_taxonomy_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_taxonomy_terms ALTER COLUMN id SET DEFAULT nextval('public.publishing_taxonomy_terms_id_seq'::regclass);


--
-- Name: publishing_version_multiple_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_multiple_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_version_multiple_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_version_single_taxonomy_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_single_taxonomy_assignments ALTER COLUMN id SET DEFAULT nextval('public.publishing_version_single_taxonomy_assignments_id_seq'::regclass);


--
-- Name: publishing_vocabularies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_vocabularies ALTER COLUMN id SET DEFAULT nextval('public.publishing_vocabularies_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: publishing_publications excl_publishing_publication_windows; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_publications
    ADD CONSTRAINT excl_publishing_publication_windows EXCLUDE USING gist (entry_id WITH =, tstzrange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((cancelled_at IS NULL));


--
-- Name: publishing_editions publishing_editions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_editions
    ADD CONSTRAINT publishing_editions_pkey PRIMARY KEY (id);


--
-- Name: publishing_entries publishing_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entries
    ADD CONSTRAINT publishing_entries_pkey PRIMARY KEY (id);


--
-- Name: publishing_entry_revisions publishing_entry_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_revisions
    ADD CONSTRAINT publishing_entry_revisions_pkey PRIMARY KEY (id);


--
-- Name: publishing_entry_slugs publishing_entry_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_slugs
    ADD CONSTRAINT publishing_entry_slugs_pkey PRIMARY KEY (id);


--
-- Name: publishing_entry_versions publishing_entry_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions
    ADD CONSTRAINT publishing_entry_versions_pkey PRIMARY KEY (id);


--
-- Name: publishing_media_files publishing_media_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_files
    ADD CONSTRAINT publishing_media_files_pkey PRIMARY KEY (id);


--
-- Name: publishing_media_usages publishing_media_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_usages
    ADD CONSTRAINT publishing_media_usages_pkey PRIMARY KEY (id);


--
-- Name: publishing_publications publishing_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_publications
    ADD CONSTRAINT publishing_publications_pkey PRIMARY KEY (id);


--
-- Name: publishing_revision_multiple_taxonomy_assignments publishing_revision_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_revision_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_revision_single_taxonomy_assignments publishing_revision_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_single_taxonomy_assignments
    ADD CONSTRAINT publishing_revision_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_taxonomy_terms publishing_taxonomy_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_taxonomy_terms
    ADD CONSTRAINT publishing_taxonomy_terms_pkey PRIMARY KEY (id);


--
-- Name: publishing_version_multiple_taxonomy_assignments publishing_version_multiple_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_multiple_taxonomy_assignments
    ADD CONSTRAINT publishing_version_multiple_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_version_single_taxonomy_assignments publishing_version_single_taxonomy_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_single_taxonomy_assignments
    ADD CONSTRAINT publishing_version_single_taxonomy_assignments_pkey PRIMARY KEY (id);


--
-- Name: publishing_vocabularies publishing_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_vocabularies
    ADD CONSTRAINT publishing_vocabularies_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_publishing_revision_multiple_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_revision_multiple_term ON public.publishing_revision_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_publishing_revision_multiple_vocabulary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_revision_multiple_vocabulary ON public.publishing_revision_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_publishing_revision_single_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_revision_single_term ON public.publishing_revision_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_publishing_revision_single_vocabulary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_revision_single_vocabulary ON public.publishing_revision_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_publishing_terms_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_terms_parent ON public.publishing_taxonomy_terms USING btree (parent_id);


--
-- Name: idx_publishing_version_multiple_taxonomy_assignments_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_version_multiple_taxonomy_assignments_filter ON public.publishing_version_multiple_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_publishing_version_multiple_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_version_multiple_term ON public.publishing_version_multiple_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_publishing_version_multiple_vocabulary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_version_multiple_vocabulary ON public.publishing_version_multiple_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: idx_publishing_version_single_taxonomy_assignments_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_version_single_taxonomy_assignments_filter ON public.publishing_version_single_taxonomy_assignments USING btree (vocabulary_key_snapshot, term_slug_snapshot, locale_snapshot);


--
-- Name: idx_publishing_version_single_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_version_single_term ON public.publishing_version_single_taxonomy_assignments USING btree (taxonomy_term_id);


--
-- Name: idx_publishing_version_single_vocabulary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_publishing_version_single_vocabulary ON public.publishing_version_single_taxonomy_assignments USING btree (vocabulary_id);


--
-- Name: index_publishing_editions_on_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_editions_on_id_and_locale ON public.publishing_editions USING btree (id, locale);


--
-- Name: index_publishing_editions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_editions_on_public_id ON public.publishing_editions USING btree (public_id);


--
-- Name: index_publishing_entries_on_current_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entries_on_current_revision_id ON public.publishing_entries USING btree (current_revision_id);


--
-- Name: index_publishing_entries_on_edition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_entries_on_edition_id ON public.publishing_entries USING btree (edition_id);


--
-- Name: index_publishing_entries_on_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entries_on_id_and_locale ON public.publishing_entries USING btree (id, locale);


--
-- Name: index_publishing_entries_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entries_on_public_id ON public.publishing_entries USING btree (public_id);


--
-- Name: index_publishing_entry_revisions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_entry_revisions_on_entry_id ON public.publishing_entry_revisions USING btree (entry_id);


--
-- Name: index_publishing_entry_revisions_on_entry_id_and_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_revisions_on_entry_id_and_sequence ON public.publishing_entry_revisions USING btree (entry_id, sequence);


--
-- Name: index_publishing_entry_revisions_on_id_and_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_revisions_on_id_and_entry_id ON public.publishing_entry_revisions USING btree (id, entry_id);


--
-- Name: index_publishing_entry_revisions_on_id_and_entry_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_revisions_on_id_and_entry_id_and_locale ON public.publishing_entry_revisions USING btree (id, entry_id, locale);


--
-- Name: index_publishing_entry_revisions_on_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_revisions_on_id_and_locale ON public.publishing_entry_revisions USING btree (id, locale);


--
-- Name: index_publishing_entry_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_revisions_on_public_id ON public.publishing_entry_revisions USING btree (public_id);


--
-- Name: index_publishing_entry_slugs_on_edition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_entry_slugs_on_edition_id ON public.publishing_entry_slugs USING btree (edition_id);


--
-- Name: index_publishing_entry_slugs_on_edition_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_slugs_on_edition_id_and_slug ON public.publishing_entry_slugs USING btree (edition_id, slug);


--
-- Name: index_publishing_entry_slugs_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_entry_slugs_on_entry_id ON public.publishing_entry_slugs USING btree (entry_id);


--
-- Name: index_publishing_entry_slugs_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_slugs_on_public_id ON public.publishing_entry_slugs USING btree (public_id);


--
-- Name: index_publishing_entry_versions_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_entry_versions_on_entry_id ON public.publishing_entry_versions USING btree (entry_id);


--
-- Name: index_publishing_entry_versions_on_entry_id_and_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_versions_on_entry_id_and_sequence ON public.publishing_entry_versions USING btree (entry_id, sequence);


--
-- Name: index_publishing_entry_versions_on_entry_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_versions_on_entry_revision_id ON public.publishing_entry_versions USING btree (entry_revision_id);


--
-- Name: index_publishing_entry_versions_on_id_and_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_versions_on_id_and_entry_id ON public.publishing_entry_versions USING btree (id, entry_id);


--
-- Name: index_publishing_entry_versions_on_id_and_entry_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_versions_on_id_and_entry_id_and_locale ON public.publishing_entry_versions USING btree (id, entry_id, locale);


--
-- Name: index_publishing_entry_versions_on_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_versions_on_id_and_locale ON public.publishing_entry_versions USING btree (id, locale);


--
-- Name: index_publishing_entry_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_entry_versions_on_public_id ON public.publishing_entry_versions USING btree (public_id);


--
-- Name: index_publishing_media_files_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_media_files_on_public_id ON public.publishing_media_files USING btree (public_id);


--
-- Name: index_publishing_media_files_on_storage_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_media_files_on_storage_key ON public.publishing_media_files USING btree (storage_key);


--
-- Name: index_publishing_media_usages_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_media_usages_on_entry_id ON public.publishing_media_usages USING btree (entry_id);


--
-- Name: index_publishing_media_usages_on_media_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_media_usages_on_media_file_id ON public.publishing_media_usages USING btree (media_file_id);


--
-- Name: index_publishing_media_usages_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_media_usages_on_public_id ON public.publishing_media_usages USING btree (public_id);


--
-- Name: index_publishing_publications_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_publications_on_entry_id ON public.publishing_publications USING btree (entry_id);


--
-- Name: index_publishing_publications_on_entry_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_publications_on_entry_version_id ON public.publishing_publications USING btree (entry_version_id);


--
-- Name: index_publishing_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_publications_on_public_id ON public.publishing_publications USING btree (public_id);


--
-- Name: index_publishing_taxonomy_terms_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_taxonomy_terms_on_public_id ON public.publishing_taxonomy_terms USING btree (public_id);


--
-- Name: index_publishing_taxonomy_terms_on_vocabulary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publishing_taxonomy_terms_on_vocabulary_id ON public.publishing_taxonomy_terms USING btree (vocabulary_id);


--
-- Name: index_publishing_vocabularies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publishing_vocabularies_on_public_id ON public.publishing_vocabularies USING btree (public_id);


--
-- Name: uidx_publishing_editions_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_editions_scope ON public.publishing_editions USING btree (audience, surface, locale);


--
-- Name: uidx_publishing_revision_media_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_revision_media_position ON public.publishing_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position") WHERE (entry_revision_id IS NOT NULL);


--
-- Name: uidx_publishing_revision_multiple_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_revision_multiple_position ON public.publishing_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, "position");


--
-- Name: uidx_publishing_revision_multiple_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_revision_multiple_term ON public.publishing_revision_multiple_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_publishing_revision_single_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_revision_single_owner ON public.publishing_revision_single_taxonomy_assignments USING btree (entry_revision_id, vocabulary_id);


--
-- Name: uidx_publishing_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_slug_canonical ON public.publishing_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_publishing_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_slug_reserved ON public.publishing_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_publishing_terms_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_terms_scope ON public.publishing_taxonomy_terms USING btree (id, vocabulary_id, locale);


--
-- Name: uidx_publishing_terms_sibling_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_terms_sibling_position ON public.publishing_taxonomy_terms USING btree (vocabulary_id, locale, parent_id, "position") NULLS NOT DISTINCT;


--
-- Name: uidx_publishing_terms_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_terms_slug ON public.publishing_taxonomy_terms USING btree (vocabulary_id, locale, slug);


--
-- Name: uidx_publishing_version_media_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_version_media_position ON public.publishing_media_usages USING btree (entry_version_id, role, field_path, block_path, "position") WHERE (entry_version_id IS NOT NULL);


--
-- Name: uidx_publishing_version_multiple_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_version_multiple_position ON public.publishing_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, "position");


--
-- Name: uidx_publishing_version_multiple_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_version_multiple_term ON public.publishing_version_multiple_taxonomy_assignments USING btree (entry_version_id, vocabulary_id, taxonomy_term_id);


--
-- Name: uidx_publishing_version_single_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_version_single_owner ON public.publishing_version_single_taxonomy_assignments USING btree (entry_version_id, vocabulary_id);


--
-- Name: uidx_publishing_vocabularies_id_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_vocabularies_id_kind ON public.publishing_vocabularies USING btree (id, kind);


--
-- Name: uidx_publishing_vocabularies_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_vocabularies_scope ON public.publishing_vocabularies USING btree (audience, surface, key);


--
-- Name: publishing_entry_revisions trg_publishing_entry_revisions_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_entry_revisions_promoted BEFORE DELETE OR UPDATE ON public.publishing_entry_revisions FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard();


--
-- Name: publishing_entry_versions trg_publishing_entry_versions_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_entry_versions_immutable BEFORE DELETE OR UPDATE ON public.publishing_entry_versions FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_entry_versions trg_publishing_entry_versions_snapshot_complete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_entry_versions_snapshot_complete AFTER INSERT ON public.publishing_entry_versions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete();


--
-- Name: publishing_revision_multiple_taxonomy_assignments trg_publishing_revision_multiple_taxonomy_assignments_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_revision_multiple_taxonomy_assignments_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_revision_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard();


--
-- Name: publishing_revision_multiple_taxonomy_assignments trg_publishing_revision_multiple_taxonomy_assignments_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_revision_multiple_taxonomy_assignments_scope AFTER INSERT OR UPDATE ON public.publishing_revision_multiple_taxonomy_assignments DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_assignment_scope_guard('publishing_entry_revisions', 'entry_revision_id');


--
-- Name: publishing_revision_single_taxonomy_assignments trg_publishing_revision_single_taxonomy_assignments_promoted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_revision_single_taxonomy_assignments_promoted BEFORE INSERT OR DELETE OR UPDATE ON public.publishing_revision_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_promoted_revision_guard();


--
-- Name: publishing_revision_single_taxonomy_assignments trg_publishing_revision_single_taxonomy_assignments_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_revision_single_taxonomy_assignments_scope AFTER INSERT OR UPDATE ON public.publishing_revision_single_taxonomy_assignments DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_assignment_scope_guard('publishing_entry_revisions', 'entry_revision_id');


--
-- Name: publishing_taxonomy_terms trg_publishing_taxonomy_terms_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_taxonomy_terms_no_delete BEFORE DELETE ON public.publishing_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_taxonomy_terms trg_publishing_terms_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_terms_hierarchy BEFORE INSERT OR UPDATE ON public.publishing_taxonomy_terms FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_term_hierarchy_guard();


--
-- Name: publishing_version_multiple_taxonomy_assignments trg_publishing_version_multiple_taxonomy_assignments_derive_sna; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_version_multiple_taxonomy_assignments_derive_sna BEFORE INSERT ON public.publishing_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_multiple_taxonomy_assignments_snapshot();


--
-- Name: publishing_version_multiple_taxonomy_assignments trg_publishing_version_multiple_taxonomy_assignments_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_version_multiple_taxonomy_assignments_immutable BEFORE DELETE OR UPDATE ON public.publishing_version_multiple_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_version_multiple_taxonomy_assignments trg_publishing_version_multiple_taxonomy_assignments_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_version_multiple_taxonomy_assignments_scope AFTER INSERT OR UPDATE ON public.publishing_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_assignment_scope_guard('publishing_entry_versions', 'entry_version_id');


--
-- Name: publishing_version_multiple_taxonomy_assignments trg_publishing_version_multiple_taxonomy_assignments_snapshot_c; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_version_multiple_taxonomy_assignments_snapshot_c AFTER INSERT ON public.publishing_version_multiple_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete();


--
-- Name: publishing_version_single_taxonomy_assignments trg_publishing_version_single_taxonomy_assignments_derive_snaps; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_version_single_taxonomy_assignments_derive_snaps BEFORE INSERT ON public.publishing_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_version_single_taxonomy_assignments_snapshot();


--
-- Name: publishing_version_single_taxonomy_assignments trg_publishing_version_single_taxonomy_assignments_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_version_single_taxonomy_assignments_immutable BEFORE DELETE OR UPDATE ON public.publishing_version_single_taxonomy_assignments FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_mutation();


--
-- Name: publishing_version_single_taxonomy_assignments trg_publishing_version_single_taxonomy_assignments_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_version_single_taxonomy_assignments_scope AFTER INSERT OR UPDATE ON public.publishing_version_single_taxonomy_assignments DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.publishing_taxonomy_assignment_scope_guard('publishing_entry_versions', 'entry_version_id');


--
-- Name: publishing_version_single_taxonomy_assignments trg_publishing_version_single_taxonomy_assignments_snapshot_com; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_publishing_version_single_taxonomy_assignments_snapshot_com AFTER INSERT ON public.publishing_version_single_taxonomy_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.publishing_assert_version_snapshot_complete();


--
-- Name: publishing_vocabularies trg_publishing_vocabularies_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_vocabularies_no_delete BEFORE DELETE ON public.publishing_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_reject_retirement_by_deletion();


--
-- Name: publishing_vocabularies trg_publishing_vocabularies_structure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_publishing_vocabularies_structure BEFORE UPDATE ON public.publishing_vocabularies FOR EACH ROW EXECUTE FUNCTION public.publishing_vocabulary_structure_guard();


--
-- Name: publishing_entries fk_publishing_entries_current_revision; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entries
    ADD CONSTRAINT fk_publishing_entries_current_revision FOREIGN KEY (current_revision_id, id) REFERENCES public.publishing_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_entries fk_publishing_entries_edition_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entries
    ADD CONSTRAINT fk_publishing_entries_edition_locale FOREIGN KEY (edition_id, locale) REFERENCES public.publishing_editions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_media_usages fk_publishing_media_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_usages
    ADD CONSTRAINT fk_publishing_media_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_media_usages fk_publishing_media_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_usages
    ADD CONSTRAINT fk_publishing_media_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_publications fk_publishing_publication_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_publications
    ADD CONSTRAINT fk_publishing_publication_version_entry FOREIGN KEY (entry_version_id, entry_id) REFERENCES public.publishing_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_entry_revisions fk_publishing_restore_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_revisions
    ADD CONSTRAINT fk_publishing_restore_revision_entry FOREIGN KEY (restored_from_revision_id, entry_id) REFERENCES public.publishing_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_entry_revisions fk_publishing_restore_version_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_revisions
    ADD CONSTRAINT fk_publishing_restore_version_entry FOREIGN KEY (restored_from_version_id, entry_id) REFERENCES public.publishing_entry_versions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_entry_revisions fk_publishing_revision_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_revisions
    ADD CONSTRAINT fk_publishing_revision_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_revision_multiple_taxonomy_assignments fk_publishing_revision_multiple_taxonomy_assignments_owner_loca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_revision_multiple_taxonomy_assignments_owner_loca FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_revision_multiple_taxonomy_assignments fk_publishing_revision_multiple_taxonomy_assignments_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_revision_multiple_taxonomy_assignments_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_revision_multiple_taxonomy_assignments fk_publishing_revision_multiple_taxonomy_assignments_vocabulary; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_revision_multiple_taxonomy_assignments_vocabulary FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_revision_single_taxonomy_assignments fk_publishing_revision_single_taxonomy_assignments_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_revision_single_taxonomy_assignments_owner_locale FOREIGN KEY (entry_revision_id, locale) REFERENCES public.publishing_entry_revisions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_revision_single_taxonomy_assignments fk_publishing_revision_single_taxonomy_assignments_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_revision_single_taxonomy_assignments_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_revision_single_taxonomy_assignments fk_publishing_revision_single_taxonomy_assignments_vocabulary_k; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_revision_single_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_revision_single_taxonomy_assignments_vocabulary_k FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_entry_slugs fk_publishing_slug_edition_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_slugs
    ADD CONSTRAINT fk_publishing_slug_edition_locale FOREIGN KEY (edition_id, locale) REFERENCES public.publishing_editions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_entry_slugs fk_publishing_slug_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_slugs
    ADD CONSTRAINT fk_publishing_slug_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_taxonomy_terms fk_publishing_terms_parent_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_taxonomy_terms
    ADD CONSTRAINT fk_publishing_terms_parent_scope FOREIGN KEY (parent_id, vocabulary_id, locale) REFERENCES public.publishing_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_taxonomy_terms fk_publishing_terms_vocabulary_kind; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_taxonomy_terms
    ADD CONSTRAINT fk_publishing_terms_vocabulary_kind FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_entry_versions fk_publishing_version_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions
    ADD CONSTRAINT fk_publishing_version_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_version_multiple_taxonomy_assignments fk_publishing_version_multiple_taxonomy_assignments_owner_local; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_version_multiple_taxonomy_assignments_owner_local FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_version_multiple_taxonomy_assignments fk_publishing_version_multiple_taxonomy_assignments_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_version_multiple_taxonomy_assignments_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_version_multiple_taxonomy_assignments fk_publishing_version_multiple_taxonomy_assignments_vocabulary_; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_multiple_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_version_multiple_taxonomy_assignments_vocabulary_ FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_entry_versions fk_publishing_version_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions
    ADD CONSTRAINT fk_publishing_version_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_entry_revisions(id, entry_id) ON DELETE RESTRICT;


--
-- Name: publishing_version_single_taxonomy_assignments fk_publishing_version_single_taxonomy_assignments_owner_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_version_single_taxonomy_assignments_owner_locale FOREIGN KEY (entry_version_id, locale) REFERENCES public.publishing_entry_versions(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_version_single_taxonomy_assignments fk_publishing_version_single_taxonomy_assignments_term_scope; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_version_single_taxonomy_assignments_term_scope FOREIGN KEY (taxonomy_term_id, vocabulary_id, locale) REFERENCES public.publishing_taxonomy_terms(id, vocabulary_id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_version_single_taxonomy_assignments fk_publishing_version_single_taxonomy_assignments_vocabulary_ki; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_version_single_taxonomy_assignments
    ADD CONSTRAINT fk_publishing_version_single_taxonomy_assignments_vocabulary_ki FOREIGN KEY (vocabulary_id, vocabulary_kind) REFERENCES public.publishing_vocabularies(id, kind) ON DELETE RESTRICT;


--
-- Name: publishing_entry_versions fk_rails_081a9cd41b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions
    ADD CONSTRAINT fk_rails_081a9cd41b FOREIGN KEY (entry_id) REFERENCES public.publishing_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_entry_revisions fk_rails_208bdb1412; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_revisions
    ADD CONSTRAINT fk_rails_208bdb1412 FOREIGN KEY (entry_id) REFERENCES public.publishing_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_media_usages fk_rails_62dd94cfa3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_usages
    ADD CONSTRAINT fk_rails_62dd94cfa3 FOREIGN KEY (entry_id) REFERENCES public.publishing_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_entries fk_rails_9a6df03a8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entries
    ADD CONSTRAINT fk_rails_9a6df03a8b FOREIGN KEY (edition_id) REFERENCES public.publishing_editions(id) ON DELETE RESTRICT;


--
-- Name: publishing_publications fk_rails_9cb374e43d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_publications
    ADD CONSTRAINT fk_rails_9cb374e43d FOREIGN KEY (entry_id) REFERENCES public.publishing_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_entry_slugs fk_rails_a4d1fecdab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_slugs
    ADD CONSTRAINT fk_rails_a4d1fecdab FOREIGN KEY (entry_id) REFERENCES public.publishing_entries(id) ON DELETE RESTRICT;


--
-- Name: publishing_entry_slugs fk_rails_d8eac5e3e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_slugs
    ADD CONSTRAINT fk_rails_d8eac5e3e2 FOREIGN KEY (edition_id) REFERENCES public.publishing_editions(id) ON DELETE RESTRICT;


--
-- Name: publishing_media_usages fk_rails_de638052fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_media_usages
    ADD CONSTRAINT fk_rails_de638052fd FOREIGN KEY (media_file_id) REFERENCES public.publishing_media_files(id) ON DELETE RESTRICT;


--
-- Name: publishing_taxonomy_terms fk_rails_df8c291df7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_taxonomy_terms
    ADD CONSTRAINT fk_rails_df8c291df7 FOREIGN KEY (vocabulary_id) REFERENCES public.publishing_vocabularies(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260801143622'),
('20260801142552'),
('20260716180000');

