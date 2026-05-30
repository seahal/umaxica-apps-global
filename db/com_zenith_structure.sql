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

CREATE UNLOGGED TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.companies (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: company_unit_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_unit_closures (
    id bigint NOT NULL,
    ancestor_id bigint NOT NULL,
    descendant_id bigint NOT NULL,
    depth integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_company_unit_closures_depth_matches_self CHECK ((((ancestor_id = descendant_id) AND (depth = 0)) OR ((ancestor_id <> descendant_id) AND (depth > 0)))),
    CONSTRAINT chk_company_unit_closures_depth_nonnegative CHECK ((depth >= 0))
);


--
-- Name: company_unit_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_unit_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_unit_closures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_unit_closures_id_seq OWNED BY public.company_unit_closures.id;


--
-- Name: company_units; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.company_units (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    parent_id bigint,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: company_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.company_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_units_id_seq OWNED BY public.company_units.id;


--
-- Name: core_com_visitor_bridges; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.core_com_visitor_bridges (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    rp_client_id character varying DEFAULT 'core_com'::character varying NOT NULL,
    audience character varying DEFAULT 'umaxica-core-com'::character varying NOT NULL,
    host character varying DEFAULT 'www.jp.umaxica.com'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: core_com_visitor_bridges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.core_com_visitor_bridges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_com_visitor_bridges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_com_visitor_bridges_id_seq OWNED BY public.core_com_visitor_bridges.id;


--
-- Name: individual_membership_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_membership_kinds (
    id bigint NOT NULL
);


--
-- Name: individual_membership_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_membership_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_membership_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_membership_kinds_id_seq OWNED BY public.individual_membership_kinds.id;


--
-- Name: individual_membership_revoke_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_membership_revoke_reasons (
    id bigint NOT NULL
);


--
-- Name: individual_membership_revoke_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_membership_revoke_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_membership_revoke_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_membership_revoke_reasons_id_seq OWNED BY public.individual_membership_revoke_reasons.id;


--
-- Name: individual_membership_states; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_membership_states (
    id bigint NOT NULL
);


--
-- Name: individual_membership_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_membership_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_membership_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_membership_states_id_seq OWNED BY public.individual_membership_states.id;


--
-- Name: individual_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individual_memberships (
    id bigint NOT NULL,
    individual_id bigint NOT NULL,
    company_id bigint NOT NULL,
    company_unit_id bigint NOT NULL,
    membership_kind_id bigint DEFAULT 0 NOT NULL,
    membership_state_id bigint DEFAULT 0 NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone,
    ends_at timestamp(6) with time zone,
    granted_by_individual_id bigint,
    approved_by_individual_id bigint,
    revoked_by_individual_id bigint,
    revoked_at timestamp(6) with time zone,
    revoke_reason_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individual_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individual_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_memberships_id_seq OWNED BY public.individual_memberships.id;


--
-- Name: individuals; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.individuals (
    id bigint NOT NULL,
    visitor_identity_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    moniker character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: individuals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.individuals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individuals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individuals_id_seq OWNED BY public.individuals.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: visitor_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_accounts (
    id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_accounts_id_seq OWNED BY public.visitor_accounts.id;


--
-- Name: visitor_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_identities (
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
-- Name: visitor_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_identities_id_seq OWNED BY public.visitor_identities.id;


--
-- Name: visitor_identity_states; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_identity_states (
    id bigint NOT NULL
);


--
-- Name: visitor_identity_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_identity_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_identity_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_identity_states_id_seq OWNED BY public.visitor_identity_states.id;


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: company_unit_closures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures ALTER COLUMN id SET DEFAULT nextval('public.company_unit_closures_id_seq'::regclass);


--
-- Name: company_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units ALTER COLUMN id SET DEFAULT nextval('public.company_units_id_seq'::regclass);


--
-- Name: core_com_visitor_bridges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_com_visitor_bridges ALTER COLUMN id SET DEFAULT nextval('public.core_com_visitor_bridges_id_seq'::regclass);


--
-- Name: individual_membership_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_kinds ALTER COLUMN id SET DEFAULT nextval('public.individual_membership_kinds_id_seq'::regclass);


--
-- Name: individual_membership_revoke_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_revoke_reasons ALTER COLUMN id SET DEFAULT nextval('public.individual_membership_revoke_reasons_id_seq'::regclass);


--
-- Name: individual_membership_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_states ALTER COLUMN id SET DEFAULT nextval('public.individual_membership_states_id_seq'::regclass);


--
-- Name: individual_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships ALTER COLUMN id SET DEFAULT nextval('public.individual_memberships_id_seq'::regclass);


--
-- Name: individuals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individuals ALTER COLUMN id SET DEFAULT nextval('public.individuals_id_seq'::regclass);


--
-- Name: visitor_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_accounts ALTER COLUMN id SET DEFAULT nextval('public.visitor_accounts_id_seq'::regclass);


--
-- Name: visitor_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identities ALTER COLUMN id SET DEFAULT nextval('public.visitor_identities_id_seq'::regclass);


--
-- Name: visitor_identity_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identity_states ALTER COLUMN id SET DEFAULT nextval('public.visitor_identity_states_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_unit_closures company_unit_closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures
    ADD CONSTRAINT company_unit_closures_pkey PRIMARY KEY (id);


--
-- Name: company_units company_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT company_units_pkey PRIMARY KEY (id);


--
-- Name: core_com_visitor_bridges core_com_visitor_bridges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_com_visitor_bridges
    ADD CONSTRAINT core_com_visitor_bridges_pkey PRIMARY KEY (id);


--
-- Name: individual_membership_kinds individual_membership_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_kinds
    ADD CONSTRAINT individual_membership_kinds_pkey PRIMARY KEY (id);


--
-- Name: individual_membership_revoke_reasons individual_membership_revoke_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_revoke_reasons
    ADD CONSTRAINT individual_membership_revoke_reasons_pkey PRIMARY KEY (id);


--
-- Name: individual_membership_states individual_membership_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_membership_states
    ADD CONSTRAINT individual_membership_states_pkey PRIMARY KEY (id);


--
-- Name: individual_memberships individual_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT individual_memberships_pkey PRIMARY KEY (id);


--
-- Name: individuals individuals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individuals
    ADD CONSTRAINT individuals_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: visitor_accounts visitor_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_accounts
    ADD CONSTRAINT visitor_accounts_pkey PRIMARY KEY (id);


--
-- Name: visitor_identities visitor_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identities
    ADD CONSTRAINT visitor_identities_pkey PRIMARY KEY (id);


--
-- Name: visitor_identity_states visitor_identity_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identity_states
    ADD CONSTRAINT visitor_identity_states_pkey PRIMARY KEY (id);


--
-- Name: idx_company_unit_closures_unique_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_unit_closures_unique_path ON public.company_unit_closures USING btree (ancestor_id, descendant_id);


--
-- Name: idx_company_units_id_company; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_units_id_company ON public.company_units USING btree (id, company_id);


--
-- Name: idx_core_com_visitor_bridges_unique_visitor_rp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_core_com_visitor_bridges_unique_visitor_rp ON public.core_com_visitor_bridges USING btree (visitor_id, rp_client_id);


--
-- Name: idx_individual_memberships_one_active_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individual_memberships_one_active_primary ON public.individual_memberships USING btree (individual_id) WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL));


--
-- Name: idx_individuals_one_per_visitor_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_individuals_one_per_visitor_identity ON public.individuals USING btree (visitor_identity_id);


--
-- Name: index_companies_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_companies_on_public_id ON public.companies USING btree (public_id);


--
-- Name: index_company_unit_closures_on_ancestor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_unit_closures_on_ancestor_id ON public.company_unit_closures USING btree (ancestor_id);


--
-- Name: index_company_unit_closures_on_descendant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_unit_closures_on_descendant_id ON public.company_unit_closures USING btree (descendant_id);


--
-- Name: index_company_units_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_units_on_company_id ON public.company_units USING btree (company_id);


--
-- Name: index_company_units_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_units_on_parent_id ON public.company_units USING btree (parent_id);


--
-- Name: index_company_units_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_company_units_on_public_id ON public.company_units USING btree (public_id);


--
-- Name: index_core_com_visitor_bridges_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_core_com_visitor_bridges_on_public_id ON public.core_com_visitor_bridges USING btree (public_id);


--
-- Name: index_core_com_visitor_bridges_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_core_com_visitor_bridges_on_visitor_id ON public.core_com_visitor_bridges USING btree (visitor_id);


--
-- Name: index_individual_memberships_on_approved_by_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_approved_by_individual_id ON public.individual_memberships USING btree (approved_by_individual_id);


--
-- Name: index_individual_memberships_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_company_id ON public.individual_memberships USING btree (company_id);


--
-- Name: index_individual_memberships_on_company_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_company_unit_id ON public.individual_memberships USING btree (company_unit_id);


--
-- Name: index_individual_memberships_on_granted_by_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_granted_by_individual_id ON public.individual_memberships USING btree (granted_by_individual_id);


--
-- Name: index_individual_memberships_on_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_individual_id ON public.individual_memberships USING btree (individual_id);


--
-- Name: index_individual_memberships_on_membership_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_membership_kind_id ON public.individual_memberships USING btree (membership_kind_id);


--
-- Name: index_individual_memberships_on_membership_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_membership_state_id ON public.individual_memberships USING btree (membership_state_id);


--
-- Name: index_individual_memberships_on_revoke_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_revoke_reason_id ON public.individual_memberships USING btree (revoke_reason_id);


--
-- Name: index_individual_memberships_on_revoked_by_individual_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individual_memberships_on_revoked_by_individual_id ON public.individual_memberships USING btree (revoked_by_individual_id);


--
-- Name: index_individuals_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_individuals_on_public_id ON public.individuals USING btree (public_id);


--
-- Name: index_individuals_on_visitor_identity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_individuals_on_visitor_identity_id ON public.individuals USING btree (visitor_identity_id);


--
-- Name: index_visitor_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_accounts_on_public_id ON public.visitor_accounts USING btree (public_id);


--
-- Name: index_visitor_accounts_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_accounts_on_visitor_id ON public.visitor_accounts USING btree (visitor_id);


--
-- Name: index_visitor_identities_on_issuer_and_subject_and_audience; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_identities_on_issuer_and_subject_and_audience ON public.visitor_identities USING btree (issuer, subject, audience);


--
-- Name: index_visitor_identities_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_identities_on_public_id ON public.visitor_identities USING btree (public_id);


--
-- Name: index_visitor_identities_on_source_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_identities_on_source_record_id ON public.visitor_identities USING btree (source_record_id);


--
-- Name: index_visitor_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_identities_on_status_id ON public.visitor_identities USING btree (status_id);


--
-- Name: company_units fk_company_units_parent_same_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT fk_company_units_parent_same_company FOREIGN KEY (parent_id, company_id) REFERENCES public.company_units(id, company_id);


--
-- Name: individual_memberships fk_individual_memberships_unit_same_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_individual_memberships_unit_same_company FOREIGN KEY (company_unit_id, company_id) REFERENCES public.company_units(id, company_id);


--
-- Name: individual_memberships fk_rails_1652eb28d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_1652eb28d9 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: individual_memberships fk_rails_282317620e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_282317620e FOREIGN KEY (individual_id) REFERENCES public.individuals(id);


--
-- Name: individual_memberships fk_rails_39edef8680; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_39edef8680 FOREIGN KEY (approved_by_individual_id) REFERENCES public.individuals(id) NOT VALID;


--
-- Name: individual_memberships fk_rails_4065f69d7a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_4065f69d7a FOREIGN KEY (company_unit_id) REFERENCES public.company_units(id);


--
-- Name: company_units fk_rails_41ac273cbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT fk_rails_41ac273cbf FOREIGN KEY (parent_id) REFERENCES public.company_units(id);


--
-- Name: company_units fk_rails_4f54e57b8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_units
    ADD CONSTRAINT fk_rails_4f54e57b8b FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: individual_memberships fk_rails_59516aa7d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_59516aa7d8 FOREIGN KEY (granted_by_individual_id) REFERENCES public.individuals(id) NOT VALID;


--
-- Name: individual_memberships fk_rails_641ad18d67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_641ad18d67 FOREIGN KEY (revoked_by_individual_id) REFERENCES public.individuals(id) NOT VALID;


--
-- Name: individual_memberships fk_rails_77f6de8097; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_77f6de8097 FOREIGN KEY (membership_kind_id) REFERENCES public.individual_membership_kinds(id) NOT VALID;


--
-- Name: individual_memberships fk_rails_790f1edfff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_790f1edfff FOREIGN KEY (membership_state_id) REFERENCES public.individual_membership_states(id) NOT VALID;


--
-- Name: individual_memberships fk_rails_ad4bcaff08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_memberships
    ADD CONSTRAINT fk_rails_ad4bcaff08 FOREIGN KEY (revoke_reason_id) REFERENCES public.individual_membership_revoke_reasons(id) NOT VALID;


--
-- Name: company_unit_closures fk_rails_aebf41d710; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures
    ADD CONSTRAINT fk_rails_aebf41d710 FOREIGN KEY (descendant_id) REFERENCES public.company_units(id);


--
-- Name: visitor_identities fk_rails_bc90881f37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_identities
    ADD CONSTRAINT fk_rails_bc90881f37 FOREIGN KEY (status_id) REFERENCES public.visitor_identity_states(id) NOT VALID;


--
-- Name: company_unit_closures fk_rails_ff8f5a8c85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_unit_closures
    ADD CONSTRAINT fk_rails_ff8f5a8c85 FOREIGN KEY (ancestor_id) REFERENCES public.company_units(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260526130001'),
('20260520143101'),
('20260520143001'),
('20260520133001'),
('20260520120001'),
('20260519161002'),
('20260513130000'),
('20260511223500'),
('20260511223458'),
('20260511223457'),
('20260511090002');

