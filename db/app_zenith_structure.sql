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
-- Name: client_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_accounts (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_accounts_id_seq OWNED BY public.client_accounts.id;


--
-- Name: client_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_identities (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    issuer character varying NOT NULL,
    subject character varying NOT NULL,
    audience character varying NOT NULL,
    source_record_id bigint NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_identities_id_seq OWNED BY public.client_identities.id;


--
-- Name: client_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_identity_states (
    id bigint NOT NULL
);


--
-- Name: client_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_identity_states_id_seq OWNED BY public.client_identity_states.id;


--
-- Name: client_profile_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_profile_statuses (
    id bigint NOT NULL
);


--
-- Name: client_profile_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_profile_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_profile_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_profile_statuses_id_seq OWNED BY public.client_profile_statuses.id;


--
-- Name: client_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_profiles (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    division_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    moniker character varying,
    public_id character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint,
    client_status_id bigint DEFAULT 0 NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: client_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_profiles_id_seq OWNED BY public.client_profiles.id;


--
-- Name: core_app_client_bridges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_app_client_bridges (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    rp_client_id character varying DEFAULT 'core_app'::character varying NOT NULL,
    audience character varying DEFAULT 'umaxica-core-app'::character varying NOT NULL,
    host character varying DEFAULT 'www.jp.umaxica.app'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: core_app_client_bridges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_app_client_bridges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_app_client_bridges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_app_client_bridges_id_seq OWNED BY public.core_app_client_bridges.id;


--
-- Name: enterprise_unit_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_unit_closures (
    id bigint NOT NULL,
    ancestor_id bigint NOT NULL,
    descendant_id bigint NOT NULL,
    depth integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_enterprise_unit_closures_depth_matches_self CHECK ((((ancestor_id = descendant_id) AND (depth = 0)) OR ((ancestor_id <> descendant_id) AND (depth > 0)))),
    CONSTRAINT chk_enterprise_unit_closures_depth_nonnegative CHECK ((depth >= 0))
);


--
-- Name: enterprise_unit_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_unit_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_unit_closures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_unit_closures_id_seq OWNED BY public.enterprise_unit_closures.id;


--
-- Name: enterprise_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprise_units (
    id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    parent_id bigint,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: enterprise_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprise_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprise_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprise_units_id_seq OWNED BY public.enterprise_units.id;


--
-- Name: enterprises; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enterprises (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: enterprises_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enterprises_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enterprises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enterprises_id_seq OWNED BY public.enterprises.id;


--
-- Name: persona_membership_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_membership_kinds (
    id bigint NOT NULL
);


--
-- Name: persona_membership_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_membership_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_membership_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_membership_kinds_id_seq OWNED BY public.persona_membership_kinds.id;


--
-- Name: persona_membership_revoke_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_membership_revoke_reasons (
    id bigint NOT NULL
);


--
-- Name: persona_membership_revoke_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_membership_revoke_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_membership_revoke_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_membership_revoke_reasons_id_seq OWNED BY public.persona_membership_revoke_reasons.id;


--
-- Name: persona_membership_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_membership_states (
    id bigint NOT NULL
);


--
-- Name: persona_membership_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_membership_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_membership_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_membership_states_id_seq OWNED BY public.persona_membership_states.id;


--
-- Name: persona_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_memberships (
    id bigint NOT NULL,
    persona_id bigint NOT NULL,
    enterprise_id bigint NOT NULL,
    enterprise_unit_id bigint NOT NULL,
    membership_kind_id bigint DEFAULT 0 NOT NULL,
    membership_state_id bigint DEFAULT 0 NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone,
    ends_at timestamp(6) with time zone,
    granted_by_persona_id bigint,
    approved_by_persona_id bigint,
    revoked_by_persona_id bigint,
    revoked_at timestamp(6) with time zone,
    revoke_reason_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: persona_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persona_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persona_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persona_memberships_id_seq OWNED BY public.persona_memberships.id;


--
-- Name: personas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personas (
    id bigint NOT NULL,
    client_identity_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: personas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personas_id_seq OWNED BY public.personas.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: client_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_accounts ALTER COLUMN id SET DEFAULT nextval('public.client_accounts_id_seq'::regclass);


--
-- Name: client_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identities ALTER COLUMN id SET DEFAULT nextval('public.client_identities_id_seq'::regclass);


--
-- Name: client_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identity_states ALTER COLUMN id SET DEFAULT nextval('public.client_identity_states_id_seq'::regclass);


--
-- Name: client_profile_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profile_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_profile_statuses_id_seq'::regclass);


--
-- Name: client_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles ALTER COLUMN id SET DEFAULT nextval('public.client_profiles_id_seq'::regclass);


--
-- Name: core_app_client_bridges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_app_client_bridges ALTER COLUMN id SET DEFAULT nextval('public.core_app_client_bridges_id_seq'::regclass);


--
-- Name: enterprise_unit_closures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures ALTER COLUMN id SET DEFAULT nextval('public.enterprise_unit_closures_id_seq'::regclass);


--
-- Name: enterprise_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units ALTER COLUMN id SET DEFAULT nextval('public.enterprise_units_id_seq'::regclass);


--
-- Name: enterprises id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprises ALTER COLUMN id SET DEFAULT nextval('public.enterprises_id_seq'::regclass);


--
-- Name: persona_membership_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_kinds ALTER COLUMN id SET DEFAULT nextval('public.persona_membership_kinds_id_seq'::regclass);


--
-- Name: persona_membership_revoke_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_revoke_reasons ALTER COLUMN id SET DEFAULT nextval('public.persona_membership_revoke_reasons_id_seq'::regclass);


--
-- Name: persona_membership_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_states ALTER COLUMN id SET DEFAULT nextval('public.persona_membership_states_id_seq'::regclass);


--
-- Name: persona_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships ALTER COLUMN id SET DEFAULT nextval('public.persona_memberships_id_seq'::regclass);


--
-- Name: personas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personas ALTER COLUMN id SET DEFAULT nextval('public.personas_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: client_accounts client_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_accounts
    ADD CONSTRAINT client_accounts_pkey PRIMARY KEY (id);


--
-- Name: client_identities client_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identities
    ADD CONSTRAINT client_identities_pkey PRIMARY KEY (id);


--
-- Name: client_identity_states client_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identity_states
    ADD CONSTRAINT client_identity_states_pkey PRIMARY KEY (id);


--
-- Name: client_profile_statuses client_profile_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profile_statuses
    ADD CONSTRAINT client_profile_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_profiles client_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_pkey PRIMARY KEY (id);


--
-- Name: core_app_client_bridges core_app_client_bridges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_app_client_bridges
    ADD CONSTRAINT core_app_client_bridges_pkey PRIMARY KEY (id);


--
-- Name: enterprise_unit_closures enterprise_unit_closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures
    ADD CONSTRAINT enterprise_unit_closures_pkey PRIMARY KEY (id);


--
-- Name: enterprise_units enterprise_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT enterprise_units_pkey PRIMARY KEY (id);


--
-- Name: enterprises enterprises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprises
    ADD CONSTRAINT enterprises_pkey PRIMARY KEY (id);


--
-- Name: persona_membership_kinds persona_membership_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_kinds
    ADD CONSTRAINT persona_membership_kinds_pkey PRIMARY KEY (id);


--
-- Name: persona_membership_revoke_reasons persona_membership_revoke_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_revoke_reasons
    ADD CONSTRAINT persona_membership_revoke_reasons_pkey PRIMARY KEY (id);


--
-- Name: persona_membership_states persona_membership_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_membership_states
    ADD CONSTRAINT persona_membership_states_pkey PRIMARY KEY (id);


--
-- Name: persona_memberships persona_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT persona_memberships_pkey PRIMARY KEY (id);


--
-- Name: personas personas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personas
    ADD CONSTRAINT personas_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_core_app_client_bridges_unique_client_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_core_app_client_bridges_unique_client_rp ON public.core_app_client_bridges USING btree (client_id, rp_client_id);


--
-- Name: idx_enterprise_unit_closures_unique_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_unit_closures_unique_path ON public.enterprise_unit_closures USING btree (ancestor_id, descendant_id);


--
-- Name: idx_enterprise_units_id_enterprise; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enterprise_units_id_enterprise ON public.enterprise_units USING btree (id, enterprise_id);


--
-- Name: idx_persona_memberships_one_active_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_persona_memberships_one_active_primary ON public.persona_memberships USING btree (persona_id) WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL));


--
-- Name: idx_personas_one_per_client_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_personas_one_per_client_identity ON public.personas USING btree (client_identity_id);


--
-- Name: index_client_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_accounts_on_public_id ON public.client_accounts USING btree (public_id);


--
-- Name: index_client_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_accounts_on_user_id ON public.client_accounts USING btree (user_id);


--
-- Name: index_client_identities_on_issuer_and_subject_and_audience; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_identities_on_issuer_and_subject_and_audience ON public.client_identities USING btree (issuer, subject, audience);


--
-- Name: index_client_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_identities_on_public_id ON public.client_identities USING btree (public_id);


--
-- Name: index_client_identities_on_source_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_identities_on_source_record_id ON public.client_identities USING btree (source_record_id);


--
-- Name: index_client_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_identities_on_status_id ON public.client_identities USING btree (status_id);


--
-- Name: index_client_profiles_on_client_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_client_status_id ON public.client_profiles USING btree (client_status_id);


--
-- Name: index_client_profiles_on_division_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_division_id ON public.client_profiles USING btree (division_id);


--
-- Name: index_client_profiles_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_profiles_on_public_id ON public.client_profiles USING btree (public_id);


--
-- Name: index_client_profiles_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_status_id ON public.client_profiles USING btree (status_id);


--
-- Name: index_client_profiles_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_user_id ON public.client_profiles USING btree (user_id);


--
-- Name: index_core_app_client_bridges_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_core_app_client_bridges_on_client_id ON public.core_app_client_bridges USING btree (client_id);


--
-- Name: index_core_app_client_bridges_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_core_app_client_bridges_on_public_id ON public.core_app_client_bridges USING btree (public_id);


--
-- Name: index_enterprise_unit_closures_on_ancestor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_unit_closures_on_ancestor_id ON public.enterprise_unit_closures USING btree (ancestor_id);


--
-- Name: index_enterprise_unit_closures_on_descendant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_unit_closures_on_descendant_id ON public.enterprise_unit_closures USING btree (descendant_id);


--
-- Name: index_enterprise_units_on_enterprise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_units_on_enterprise_id ON public.enterprise_units USING btree (enterprise_id);


--
-- Name: index_enterprise_units_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enterprise_units_on_parent_id ON public.enterprise_units USING btree (parent_id);


--
-- Name: index_enterprise_units_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enterprise_units_on_public_id ON public.enterprise_units USING btree (public_id);


--
-- Name: index_enterprises_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enterprises_on_public_id ON public.enterprises USING btree (public_id);


--
-- Name: index_persona_memberships_on_approved_by_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_approved_by_persona_id ON public.persona_memberships USING btree (approved_by_persona_id);


--
-- Name: index_persona_memberships_on_enterprise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_enterprise_id ON public.persona_memberships USING btree (enterprise_id);


--
-- Name: index_persona_memberships_on_enterprise_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_enterprise_unit_id ON public.persona_memberships USING btree (enterprise_unit_id);


--
-- Name: index_persona_memberships_on_granted_by_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_granted_by_persona_id ON public.persona_memberships USING btree (granted_by_persona_id);


--
-- Name: index_persona_memberships_on_membership_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_membership_kind_id ON public.persona_memberships USING btree (membership_kind_id);


--
-- Name: index_persona_memberships_on_membership_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_membership_state_id ON public.persona_memberships USING btree (membership_state_id);


--
-- Name: index_persona_memberships_on_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_persona_id ON public.persona_memberships USING btree (persona_id);


--
-- Name: index_persona_memberships_on_revoke_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_revoke_reason_id ON public.persona_memberships USING btree (revoke_reason_id);


--
-- Name: index_persona_memberships_on_revoked_by_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_memberships_on_revoked_by_persona_id ON public.persona_memberships USING btree (revoked_by_persona_id);


--
-- Name: index_personas_on_client_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_personas_on_client_identity_id ON public.personas USING btree (client_identity_id);


--
-- Name: index_personas_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_personas_on_public_id ON public.personas USING btree (public_id);


--
-- Name: enterprise_units fk_enterprise_units_parent_same_enterprise; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT fk_enterprise_units_parent_same_enterprise FOREIGN KEY (parent_id, enterprise_id) REFERENCES public.enterprise_units(id, enterprise_id);


--
-- Name: persona_memberships fk_persona_memberships_unit_same_enterprise; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_persona_memberships_unit_same_enterprise FOREIGN KEY (enterprise_unit_id, enterprise_id) REFERENCES public.enterprise_units(id, enterprise_id);


--
-- Name: persona_memberships fk_rails_01b7fc5176; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_01b7fc5176 FOREIGN KEY (persona_id) REFERENCES public.personas(id);


--
-- Name: persona_memberships fk_rails_0d7f5f74b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_0d7f5f74b1 FOREIGN KEY (revoke_reason_id) REFERENCES public.persona_membership_revoke_reasons(id) NOT VALID;


--
-- Name: persona_memberships fk_rails_182816542a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_182816542a FOREIGN KEY (membership_state_id) REFERENCES public.persona_membership_states(id) NOT VALID;


--
-- Name: client_identities fk_rails_3045b2b3f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_identities
    ADD CONSTRAINT fk_rails_3045b2b3f6 FOREIGN KEY (status_id) REFERENCES public.client_identity_states(id) NOT VALID;


--
-- Name: persona_memberships fk_rails_4f3c994599; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_4f3c994599 FOREIGN KEY (membership_kind_id) REFERENCES public.persona_membership_kinds(id) NOT VALID;


--
-- Name: client_profiles fk_rails_510843a98e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT fk_rails_510843a98e FOREIGN KEY (client_status_id) REFERENCES public.client_profile_statuses(id) NOT VALID;


--
-- Name: persona_memberships fk_rails_523bf01343; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_523bf01343 FOREIGN KEY (enterprise_unit_id) REFERENCES public.enterprise_units(id);


--
-- Name: persona_memberships fk_rails_529c28deb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_529c28deb1 FOREIGN KEY (granted_by_persona_id) REFERENCES public.personas(id) NOT VALID;


--
-- Name: enterprise_units fk_rails_7793aa24bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT fk_rails_7793aa24bc FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: enterprise_unit_closures fk_rails_8e0192642e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures
    ADD CONSTRAINT fk_rails_8e0192642e FOREIGN KEY (descendant_id) REFERENCES public.enterprise_units(id);


--
-- Name: persona_memberships fk_rails_b787ae6cc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_b787ae6cc4 FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: enterprise_units fk_rails_ba9e99577f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_units
    ADD CONSTRAINT fk_rails_ba9e99577f FOREIGN KEY (parent_id) REFERENCES public.enterprise_units(id);


--
-- Name: client_profiles fk_rails_c49c0906dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT fk_rails_c49c0906dc FOREIGN KEY (status_id) REFERENCES public.client_profile_statuses(id) NOT VALID;


--
-- Name: persona_memberships fk_rails_cdfe640663; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_cdfe640663 FOREIGN KEY (revoked_by_persona_id) REFERENCES public.personas(id) NOT VALID;


--
-- Name: persona_memberships fk_rails_e031c03097; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_memberships
    ADD CONSTRAINT fk_rails_e031c03097 FOREIGN KEY (approved_by_persona_id) REFERENCES public.personas(id) NOT VALID;


--
-- Name: enterprise_unit_closures fk_rails_f304c4c398; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enterprise_unit_closures
    ADD CONSTRAINT fk_rails_f304c4c398 FOREIGN KEY (ancestor_id) REFERENCES public.enterprise_units(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260612000001'),
('20260530031000'),
('20260526130000'),
('20260520143100'),
('20260520143003'),
('20260520143000'),
('20260520133000'),
('20260520120000'),
('20260519172000'),
('20260519161000'),
('20260511223500'),
('20260511223447'),
('20260511223446'),
('20260511090000');

