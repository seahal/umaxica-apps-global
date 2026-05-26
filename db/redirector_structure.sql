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
-- Name: app_jump_links; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.app_jump_links (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    destination_url text NOT NULL,
    status_id integer DEFAULT 0 NOT NULL,
    purged_at timestamp(6) with time zone NOT NULL,
    max_uses integer DEFAULT 0 NOT NULL,
    uses_count integer DEFAULT 0 NOT NULL,
    policy jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: app_jump_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.app_jump_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_jump_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_jump_links_id_seq OWNED BY public.app_jump_links.id;


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
-- Name: com_jump_links; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_jump_links (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    destination_url text NOT NULL,
    status_id integer DEFAULT 0 NOT NULL,
    purged_at timestamp(6) with time zone NOT NULL,
    max_uses integer DEFAULT 0 NOT NULL,
    uses_count integer DEFAULT 0 NOT NULL,
    policy jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: com_jump_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_jump_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_jump_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_jump_links_id_seq OWNED BY public.com_jump_links.id;


--
-- Name: org_jump_links; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.org_jump_links (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    destination_url text NOT NULL,
    status_id integer DEFAULT 0 NOT NULL,
    purged_at timestamp(6) with time zone NOT NULL,
    max_uses integer DEFAULT 0 NOT NULL,
    uses_count integer DEFAULT 0 NOT NULL,
    policy jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: org_jump_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.org_jump_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_jump_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_jump_links_id_seq OWNED BY public.org_jump_links.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: app_jump_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_jump_links ALTER COLUMN id SET DEFAULT nextval('public.app_jump_links_id_seq'::regclass);


--
-- Name: com_jump_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_jump_links ALTER COLUMN id SET DEFAULT nextval('public.com_jump_links_id_seq'::regclass);


--
-- Name: org_jump_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_jump_links ALTER COLUMN id SET DEFAULT nextval('public.org_jump_links_id_seq'::regclass);


--
-- Name: app_jump_links app_jump_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_jump_links
    ADD CONSTRAINT app_jump_links_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: com_jump_links com_jump_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_jump_links
    ADD CONSTRAINT com_jump_links_pkey PRIMARY KEY (id);


--
-- Name: org_jump_links org_jump_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_jump_links
    ADD CONSTRAINT org_jump_links_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_app_jump_links_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_app_jump_links_on_public_id ON public.app_jump_links USING btree (public_id);


--
-- Name: index_app_jump_links_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_jump_links_on_purged_at ON public.app_jump_links USING btree (purged_at);


--
-- Name: index_app_jump_links_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_app_jump_links_on_status_id ON public.app_jump_links USING btree (status_id);


--
-- Name: index_com_jump_links_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_jump_links_on_public_id ON public.com_jump_links USING btree (public_id);


--
-- Name: index_com_jump_links_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_jump_links_on_purged_at ON public.com_jump_links USING btree (purged_at);


--
-- Name: index_com_jump_links_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_jump_links_on_status_id ON public.com_jump_links USING btree (status_id);


--
-- Name: index_org_jump_links_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_jump_links_on_public_id ON public.org_jump_links USING btree (public_id);


--
-- Name: index_org_jump_links_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_jump_links_on_purged_at ON public.org_jump_links USING btree (purged_at);


--
-- Name: index_org_jump_links_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_jump_links_on_status_id ON public.org_jump_links USING btree (status_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260518044610'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260427000000');

