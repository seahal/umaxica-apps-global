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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: publishing_editions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.publishing_editions (
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
    CONSTRAINT chk_publishing_editions_surface CHECK (((surface)::text = ANY ((ARRAY['info'::character varying, 'docs'::character varying, 'news'::character varying, 'help'::character varying])::text[])))
);


--
-- Name: publishing_editions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.publishing_editions_id_seq
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

CREATE UNLOGGED TABLE public.publishing_entries (
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

CREATE UNLOGGED SEQUENCE public.publishing_entries_id_seq
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

CREATE UNLOGGED TABLE public.publishing_entry_revisions (
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

CREATE UNLOGGED SEQUENCE public.publishing_entry_revisions_id_seq
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

CREATE UNLOGGED TABLE public.publishing_entry_slugs (
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

CREATE UNLOGGED SEQUENCE public.publishing_entry_slugs_id_seq
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

CREATE UNLOGGED TABLE public.publishing_entry_versions (
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

CREATE UNLOGGED SEQUENCE public.publishing_entry_versions_id_seq
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

CREATE UNLOGGED TABLE public.publishing_media_files (
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

CREATE UNLOGGED SEQUENCE public.publishing_media_files_id_seq
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

CREATE UNLOGGED TABLE public.publishing_media_usages (
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

CREATE UNLOGGED SEQUENCE public.publishing_media_usages_id_seq
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

CREATE UNLOGGED TABLE public.publishing_publications (
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

CREATE UNLOGGED SEQUENCE public.publishing_publications_id_seq
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
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
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


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
-- Name: uidx_publishing_editions_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_editions_scope ON public.publishing_editions USING btree (audience, surface, locale);


--
-- Name: uidx_publishing_revision_media_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_revision_media_position ON public.publishing_media_usages USING btree (entry_revision_id, role, field_path, block_path, "position") WHERE (entry_revision_id IS NOT NULL);


--
-- Name: uidx_publishing_slug_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_slug_canonical ON public.publishing_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'canonical'::text);


--
-- Name: uidx_publishing_slug_reserved; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_slug_reserved ON public.publishing_entry_slugs USING btree (entry_id) WHERE ((state)::text = 'reserved'::text);


--
-- Name: uidx_publishing_version_media_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_publishing_version_media_position ON public.publishing_media_usages USING btree (entry_version_id, role, field_path, block_path, "position") WHERE (entry_version_id IS NOT NULL);


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
-- Name: publishing_entry_versions fk_publishing_version_entry_locale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions
    ADD CONSTRAINT fk_publishing_version_entry_locale FOREIGN KEY (entry_id, locale) REFERENCES public.publishing_entries(id, locale) ON DELETE RESTRICT;


--
-- Name: publishing_entry_versions fk_publishing_version_revision_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publishing_entry_versions
    ADD CONSTRAINT fk_publishing_version_revision_entry FOREIGN KEY (entry_revision_id, entry_id) REFERENCES public.publishing_entry_revisions(id, entry_id) ON DELETE RESTRICT;


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
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260716180000');

