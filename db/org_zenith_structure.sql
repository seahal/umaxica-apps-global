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
-- Name: agent_membership_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_membership_kinds (
    id bigint NOT NULL
);


--
-- Name: agent_membership_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_membership_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_membership_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_membership_kinds_id_seq OWNED BY public.agent_membership_kinds.id;


--
-- Name: agent_membership_revoke_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_membership_revoke_reasons (
    id bigint NOT NULL
);


--
-- Name: agent_membership_revoke_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_membership_revoke_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_membership_revoke_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_membership_revoke_reasons_id_seq OWNED BY public.agent_membership_revoke_reasons.id;


--
-- Name: agent_membership_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_membership_states (
    id bigint NOT NULL
);


--
-- Name: agent_membership_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_membership_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_membership_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_membership_states_id_seq OWNED BY public.agent_membership_states.id;


--
-- Name: agent_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_memberships (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    bureau_unit_id bigint NOT NULL,
    membership_kind_id bigint DEFAULT 0 NOT NULL,
    membership_state_id bigint DEFAULT 0 NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone,
    ends_at timestamp(6) with time zone,
    granted_by_agent_id bigint,
    approved_by_agent_id bigint,
    revoked_by_agent_id bigint,
    revoked_at timestamp(6) with time zone,
    revoke_reason_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agent_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_memberships_id_seq OWNED BY public.agent_memberships.id;


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id bigint NOT NULL,
    operator_identity_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agents_id_seq OWNED BY public.agents.id;


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
-- Name: bureau_unit_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_unit_closures (
    id bigint NOT NULL,
    ancestor_id bigint NOT NULL,
    descendant_id bigint NOT NULL,
    depth integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_bureau_unit_closures_depth_matches_self CHECK ((((ancestor_id = descendant_id) AND (depth = 0)) OR ((ancestor_id <> descendant_id) AND (depth > 0)))),
    CONSTRAINT chk_bureau_unit_closures_depth_nonnegative CHECK ((depth >= 0))
);


--
-- Name: bureau_unit_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_unit_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_unit_closures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_unit_closures_id_seq OWNED BY public.bureau_unit_closures.id;


--
-- Name: bureau_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureau_units (
    id bigint NOT NULL,
    bureau_id bigint NOT NULL,
    parent_id bigint,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: bureau_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureau_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureau_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureau_units_id_seq OWNED BY public.bureau_units.id;


--
-- Name: bureaus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bureaus (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: bureaus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bureaus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bureaus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bureaus_id_seq OWNED BY public.bureaus.id;


--
-- Name: core_org_operator_bridges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_org_operator_bridges (
    id bigint NOT NULL,
    operator_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    rp_client_id character varying DEFAULT 'core_org'::character varying NOT NULL,
    audience character varying DEFAULT 'umaxica-core-org'::character varying NOT NULL,
    host character varying DEFAULT 'www.jp.umaxica.org'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: core_org_operator_bridges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_org_operator_bridges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_org_operator_bridges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_org_operator_bridges_id_seq OWNED BY public.core_org_operator_bridges.id;


--
-- Name: operator_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_accounts (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    staff_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_accounts_id_seq OWNED BY public.operator_accounts.id;


--
-- Name: operator_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_identities (
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
-- Name: operator_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_identities_id_seq OWNED BY public.operator_identities.id;


--
-- Name: operator_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_identity_states (
    id bigint NOT NULL
);


--
-- Name: operator_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_identity_states_id_seq OWNED BY public.operator_identity_states.id;


--
-- Name: operator_workspace_account_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_workspace_account_memberships (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    operator_workspace_account_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_workspace_account_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_workspace_account_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_workspace_account_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_workspace_account_memberships_id_seq OWNED BY public.operator_workspace_account_memberships.id;


--
-- Name: operator_workspace_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operator_workspace_accounts (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    department_id bigint,
    public_id character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: operator_workspace_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_workspace_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_workspace_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_workspace_accounts_id_seq OWNED BY public.operator_workspace_accounts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: agent_membership_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_kinds ALTER COLUMN id SET DEFAULT nextval('public.agent_membership_kinds_id_seq'::regclass);


--
-- Name: agent_membership_revoke_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_revoke_reasons ALTER COLUMN id SET DEFAULT nextval('public.agent_membership_revoke_reasons_id_seq'::regclass);


--
-- Name: agent_membership_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_states ALTER COLUMN id SET DEFAULT nextval('public.agent_membership_states_id_seq'::regclass);


--
-- Name: agent_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships ALTER COLUMN id SET DEFAULT nextval('public.agent_memberships_id_seq'::regclass);


--
-- Name: agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents ALTER COLUMN id SET DEFAULT nextval('public.agents_id_seq'::regclass);


--
-- Name: bureau_unit_closures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures ALTER COLUMN id SET DEFAULT nextval('public.bureau_unit_closures_id_seq'::regclass);


--
-- Name: bureau_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units ALTER COLUMN id SET DEFAULT nextval('public.bureau_units_id_seq'::regclass);


--
-- Name: bureaus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureaus ALTER COLUMN id SET DEFAULT nextval('public.bureaus_id_seq'::regclass);


--
-- Name: core_org_operator_bridges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_org_operator_bridges ALTER COLUMN id SET DEFAULT nextval('public.core_org_operator_bridges_id_seq'::regclass);


--
-- Name: operator_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts ALTER COLUMN id SET DEFAULT nextval('public.operator_accounts_id_seq'::regclass);


--
-- Name: operator_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identities ALTER COLUMN id SET DEFAULT nextval('public.operator_identities_id_seq'::regclass);


--
-- Name: operator_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identity_states ALTER COLUMN id SET DEFAULT nextval('public.operator_identity_states_id_seq'::regclass);


--
-- Name: operator_workspace_account_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_memberships ALTER COLUMN id SET DEFAULT nextval('public.operator_workspace_account_memberships_id_seq'::regclass);


--
-- Name: operator_workspace_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_accounts ALTER COLUMN id SET DEFAULT nextval('public.operator_workspace_accounts_id_seq'::regclass);


--
-- Name: agent_membership_kinds agent_membership_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_kinds
    ADD CONSTRAINT agent_membership_kinds_pkey PRIMARY KEY (id);


--
-- Name: agent_membership_revoke_reasons agent_membership_revoke_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_revoke_reasons
    ADD CONSTRAINT agent_membership_revoke_reasons_pkey PRIMARY KEY (id);


--
-- Name: agent_membership_states agent_membership_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_membership_states
    ADD CONSTRAINT agent_membership_states_pkey PRIMARY KEY (id);


--
-- Name: agent_memberships agent_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT agent_memberships_pkey PRIMARY KEY (id);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: bureau_unit_closures bureau_unit_closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures
    ADD CONSTRAINT bureau_unit_closures_pkey PRIMARY KEY (id);


--
-- Name: bureau_units bureau_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT bureau_units_pkey PRIMARY KEY (id);


--
-- Name: bureaus bureaus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureaus
    ADD CONSTRAINT bureaus_pkey PRIMARY KEY (id);


--
-- Name: core_org_operator_bridges core_org_operator_bridges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_org_operator_bridges
    ADD CONSTRAINT core_org_operator_bridges_pkey PRIMARY KEY (id);


--
-- Name: operator_accounts operator_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts
    ADD CONSTRAINT operator_accounts_pkey PRIMARY KEY (id);


--
-- Name: operator_identities operator_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identities
    ADD CONSTRAINT operator_identities_pkey PRIMARY KEY (id);


--
-- Name: operator_identity_states operator_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identity_states
    ADD CONSTRAINT operator_identity_states_pkey PRIMARY KEY (id);


--
-- Name: operator_workspace_account_memberships operator_workspace_account_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_memberships
    ADD CONSTRAINT operator_workspace_account_memberships_pkey PRIMARY KEY (id);


--
-- Name: operator_workspace_accounts operator_workspace_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_accounts
    ADD CONSTRAINT operator_workspace_accounts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_agent_memberships_one_active_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_memberships_one_active_primary ON public.agent_memberships USING btree (agent_id) WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL));


--
-- Name: idx_agents_one_per_operator_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agents_one_per_operator_identity ON public.agents USING btree (operator_identity_id);


--
-- Name: idx_bureau_unit_closures_unique_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_unit_closures_unique_path ON public.bureau_unit_closures USING btree (ancestor_id, descendant_id);


--
-- Name: idx_bureau_units_id_bureau; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bureau_units_id_bureau ON public.bureau_units USING btree (id, bureau_id);


--
-- Name: idx_core_org_operator_bridges_unique_operator_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_core_org_operator_bridges_unique_operator_rp ON public.core_org_operator_bridges USING btree (operator_id, rp_client_id);


--
-- Name: idx_operator_workspace_memberships_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_workspace_memberships_on_account_id ON public.operator_workspace_account_memberships USING btree (operator_workspace_account_id);


--
-- Name: idx_operator_workspace_memberships_on_staff_and_account; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_operator_workspace_memberships_on_staff_and_account ON public.operator_workspace_account_memberships USING btree (staff_id, operator_workspace_account_id);


--
-- Name: index_agent_memberships_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_agent_id ON public.agent_memberships USING btree (agent_id);


--
-- Name: index_agent_memberships_on_approved_by_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_approved_by_agent_id ON public.agent_memberships USING btree (approved_by_agent_id);


--
-- Name: index_agent_memberships_on_bureau_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_bureau_id ON public.agent_memberships USING btree (bureau_id);


--
-- Name: index_agent_memberships_on_bureau_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_bureau_unit_id ON public.agent_memberships USING btree (bureau_unit_id);


--
-- Name: index_agent_memberships_on_granted_by_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_granted_by_agent_id ON public.agent_memberships USING btree (granted_by_agent_id);


--
-- Name: index_agent_memberships_on_membership_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_membership_kind_id ON public.agent_memberships USING btree (membership_kind_id);


--
-- Name: index_agent_memberships_on_membership_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_membership_state_id ON public.agent_memberships USING btree (membership_state_id);


--
-- Name: index_agent_memberships_on_revoke_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_revoke_reason_id ON public.agent_memberships USING btree (revoke_reason_id);


--
-- Name: index_agent_memberships_on_revoked_by_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_memberships_on_revoked_by_agent_id ON public.agent_memberships USING btree (revoked_by_agent_id);


--
-- Name: index_agents_on_operator_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agents_on_operator_identity_id ON public.agents USING btree (operator_identity_id);


--
-- Name: index_agents_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agents_on_public_id ON public.agents USING btree (public_id);


--
-- Name: index_bureau_unit_closures_on_ancestor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_unit_closures_on_ancestor_id ON public.bureau_unit_closures USING btree (ancestor_id);


--
-- Name: index_bureau_unit_closures_on_descendant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_unit_closures_on_descendant_id ON public.bureau_unit_closures USING btree (descendant_id);


--
-- Name: index_bureau_units_on_bureau_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_units_on_bureau_id ON public.bureau_units USING btree (bureau_id);


--
-- Name: index_bureau_units_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bureau_units_on_parent_id ON public.bureau_units USING btree (parent_id);


--
-- Name: index_bureau_units_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bureau_units_on_public_id ON public.bureau_units USING btree (public_id);


--
-- Name: index_bureaus_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bureaus_on_public_id ON public.bureaus USING btree (public_id);


--
-- Name: index_core_org_operator_bridges_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_core_org_operator_bridges_on_operator_id ON public.core_org_operator_bridges USING btree (operator_id);


--
-- Name: index_core_org_operator_bridges_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_core_org_operator_bridges_on_public_id ON public.core_org_operator_bridges USING btree (public_id);


--
-- Name: index_operator_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_accounts_on_public_id ON public.operator_accounts USING btree (public_id);


--
-- Name: index_operator_accounts_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_accounts_on_staff_id ON public.operator_accounts USING btree (staff_id);


--
-- Name: index_operator_identities_on_issuer_and_subject_and_audience; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_identities_on_issuer_and_subject_and_audience ON public.operator_identities USING btree (issuer, subject, audience);


--
-- Name: index_operator_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_identities_on_public_id ON public.operator_identities USING btree (public_id);


--
-- Name: index_operator_identities_on_source_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_identities_on_source_record_id ON public.operator_identities USING btree (source_record_id);


--
-- Name: index_operator_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_identities_on_status_id ON public.operator_identities USING btree (status_id);


--
-- Name: index_operator_workspace_accounts_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_workspace_accounts_on_department_id ON public.operator_workspace_accounts USING btree (department_id);


--
-- Name: index_operator_workspace_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_workspace_accounts_on_public_id ON public.operator_workspace_accounts USING btree (public_id);


--
-- Name: index_operator_workspace_accounts_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_workspace_accounts_on_staff_id ON public.operator_workspace_accounts USING btree (staff_id);


--
-- Name: index_operator_workspace_accounts_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_workspace_accounts_on_status_id ON public.operator_workspace_accounts USING btree (status_id);


--
-- Name: agent_memberships fk_agent_memberships_unit_same_bureau; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_agent_memberships_unit_same_bureau FOREIGN KEY (bureau_unit_id, bureau_id) REFERENCES public.bureau_units(id, bureau_id);


--
-- Name: bureau_units fk_bureau_units_parent_same_bureau; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT fk_bureau_units_parent_same_bureau FOREIGN KEY (parent_id, bureau_id) REFERENCES public.bureau_units(id, bureau_id);


--
-- Name: agent_memberships fk_rails_05081537eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_05081537eb FOREIGN KEY (revoke_reason_id) REFERENCES public.agent_membership_revoke_reasons(id) NOT VALID;


--
-- Name: bureau_unit_closures fk_rails_098ea54ffa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures
    ADD CONSTRAINT fk_rails_098ea54ffa FOREIGN KEY (descendant_id) REFERENCES public.bureau_units(id);


--
-- Name: bureau_units fk_rails_0eea1d47b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT fk_rails_0eea1d47b8 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: agent_memberships fk_rails_1a95fbbc46; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_1a95fbbc46 FOREIGN KEY (membership_state_id) REFERENCES public.agent_membership_states(id) NOT VALID;


--
-- Name: agent_memberships fk_rails_27ba6b71fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_27ba6b71fd FOREIGN KEY (revoked_by_agent_id) REFERENCES public.agents(id) NOT VALID;


--
-- Name: agent_memberships fk_rails_35c0a01ca1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_35c0a01ca1 FOREIGN KEY (bureau_unit_id) REFERENCES public.bureau_units(id);


--
-- Name: operator_workspace_account_memberships fk_rails_46775ba732; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_workspace_account_memberships
    ADD CONSTRAINT fk_rails_46775ba732 FOREIGN KEY (operator_workspace_account_id) REFERENCES public.operator_workspace_accounts(id) ON DELETE CASCADE NOT VALID;


--
-- Name: agent_memberships fk_rails_598d6fdb3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_598d6fdb3c FOREIGN KEY (approved_by_agent_id) REFERENCES public.agents(id) NOT VALID;


--
-- Name: agent_memberships fk_rails_684fa8a568; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_684fa8a568 FOREIGN KEY (bureau_id) REFERENCES public.bureaus(id);


--
-- Name: agent_memberships fk_rails_80322cea57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_80322cea57 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: operator_identities fk_rails_8d441d6c30; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identities
    ADD CONSTRAINT fk_rails_8d441d6c30 FOREIGN KEY (status_id) REFERENCES public.operator_identity_states(id);


--
-- Name: bureau_units fk_rails_b69a74fbbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_units
    ADD CONSTRAINT fk_rails_b69a74fbbb FOREIGN KEY (parent_id) REFERENCES public.bureau_units(id);


--
-- Name: bureau_unit_closures fk_rails_d60846037f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bureau_unit_closures
    ADD CONSTRAINT fk_rails_d60846037f FOREIGN KEY (ancestor_id) REFERENCES public.bureau_units(id);


--
-- Name: agent_memberships fk_rails_ed6c87c035; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_ed6c87c035 FOREIGN KEY (membership_kind_id) REFERENCES public.agent_membership_kinds(id) NOT VALID;


--
-- Name: agent_memberships fk_rails_feb3a1d9a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_memberships
    ADD CONSTRAINT fk_rails_feb3a1d9a5 FOREIGN KEY (granted_by_agent_id) REFERENCES public.agents(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260612000001'),
('20260526130002'),
('20260520143102'),
('20260520143002'),
('20260520133002'),
('20260520120002'),
('20260519172002'),
('20260519161001'),
('20260518181000'),
('20260511223500'),
('20260511223458'),
('20260511223457'),
('20260511090001');

