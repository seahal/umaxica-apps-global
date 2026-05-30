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
-- Name: com_post_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_categories (
    id bigint NOT NULL,
    com_post_category_master_id bigint DEFAULT 0 NOT NULL,
    com_post_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_post_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_categories_id_seq OWNED BY public.com_post_categories.id;


--
-- Name: com_post_category_masters; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_category_masters (
    id bigint NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: com_post_category_masters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_category_masters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_category_masters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_category_masters_id_seq OWNED BY public.com_post_category_masters.id;


--
-- Name: com_post_review_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_review_statuses (
    id bigint NOT NULL
);


--
-- Name: com_post_review_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_review_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_review_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_review_statuses_id_seq OWNED BY public.com_post_review_statuses.id;


--
-- Name: com_post_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_reviews (
    id bigint NOT NULL,
    comment text,
    decided_at timestamp with time zone,
    com_post_id bigint NOT NULL,
    com_post_review_status_id bigint NOT NULL,
    reviewer_actor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_post_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_reviews_id_seq OWNED BY public.com_post_reviews.id;


--
-- Name: com_post_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_revisions (
    id bigint NOT NULL,
    body text,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    com_post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_post_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_revisions_id_seq OWNED BY public.com_post_revisions.id;


--
-- Name: com_post_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_statuses (
    id bigint NOT NULL
);


--
-- Name: com_post_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_statuses_id_seq OWNED BY public.com_post_statuses.id;


--
-- Name: com_post_tag_masters; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_tag_masters (
    id bigint NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: com_post_tag_masters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_tag_masters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_tag_masters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_tag_masters_id_seq OWNED BY public.com_post_tag_masters.id;


--
-- Name: com_post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_tags (
    id bigint NOT NULL,
    com_post_id bigint NOT NULL,
    com_post_tag_master_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_post_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_tags_id_seq OWNED BY public.com_post_tags.id;


--
-- Name: com_post_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_post_versions (
    id bigint NOT NULL,
    body text,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    com_post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_post_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_post_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_post_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_post_versions_id_seq OWNED BY public.com_post_versions.id;


--
-- Name: com_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.com_posts (
    id bigint NOT NULL,
    author_avatar_id bigint NOT NULL,
    body text NOT NULL,
    created_by_actor_id bigint NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    latest_com_post_revision_id bigint,
    latest_com_post_version_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    permalink character varying(200) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    com_post_status_id bigint NOT NULL,
    public_id character varying NOT NULL,
    published_at timestamp with time zone NOT NULL,
    published_by_actor_id bigint,
    redirect_url character varying,
    response_mode character varying DEFAULT 'html'::character varying NOT NULL,
    revision_key character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: com_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.com_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: com_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.com_posts_id_seq OWNED BY public.com_posts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: com_post_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_categories ALTER COLUMN id SET DEFAULT nextval('public.com_post_categories_id_seq'::regclass);


--
-- Name: com_post_category_masters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_category_masters ALTER COLUMN id SET DEFAULT nextval('public.com_post_category_masters_id_seq'::regclass);


--
-- Name: com_post_review_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_review_statuses ALTER COLUMN id SET DEFAULT nextval('public.com_post_review_statuses_id_seq'::regclass);


--
-- Name: com_post_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_reviews ALTER COLUMN id SET DEFAULT nextval('public.com_post_reviews_id_seq'::regclass);


--
-- Name: com_post_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_revisions ALTER COLUMN id SET DEFAULT nextval('public.com_post_revisions_id_seq'::regclass);


--
-- Name: com_post_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_statuses ALTER COLUMN id SET DEFAULT nextval('public.com_post_statuses_id_seq'::regclass);


--
-- Name: com_post_tag_masters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_tag_masters ALTER COLUMN id SET DEFAULT nextval('public.com_post_tag_masters_id_seq'::regclass);


--
-- Name: com_post_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_tags ALTER COLUMN id SET DEFAULT nextval('public.com_post_tags_id_seq'::regclass);


--
-- Name: com_post_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_versions ALTER COLUMN id SET DEFAULT nextval('public.com_post_versions_id_seq'::regclass);


--
-- Name: com_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_posts ALTER COLUMN id SET DEFAULT nextval('public.com_posts_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: com_post_revisions chk_com_post_revisions_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_revisions
    ADD CONSTRAINT chk_com_post_revisions_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: com_post_revisions chk_com_post_revisions_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_revisions
    ADD CONSTRAINT chk_com_post_revisions_response_mode CHECK (((response_mode)::text = ANY (ARRAY[('html'::character varying)::text, ('text'::character varying)::text, ('pdf'::character varying)::text, ('redirect'::character varying)::text]))) NOT VALID;


--
-- Name: com_post_versions chk_com_post_versions_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_versions
    ADD CONSTRAINT chk_com_post_versions_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: com_post_versions chk_com_post_versions_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_versions
    ADD CONSTRAINT chk_com_post_versions_response_mode CHECK (((response_mode)::text = ANY (ARRAY[('html'::character varying)::text, ('text'::character varying)::text, ('pdf'::character varying)::text, ('redirect'::character varying)::text]))) NOT VALID;


--
-- Name: com_posts chk_com_posts_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_posts
    ADD CONSTRAINT chk_com_posts_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: com_posts chk_com_posts_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_posts
    ADD CONSTRAINT chk_com_posts_response_mode CHECK (((response_mode)::text = ANY (ARRAY[('html'::character varying)::text, ('text'::character varying)::text, ('pdf'::character varying)::text, ('redirect'::character varying)::text]))) NOT VALID;


--
-- Name: com_post_categories com_post_categories_master_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_categories
    ADD CONSTRAINT com_post_categories_master_id_non_negative CHECK ((com_post_category_master_id >= 0)) NOT VALID;


--
-- Name: com_post_categories com_post_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_categories
    ADD CONSTRAINT com_post_categories_pkey PRIMARY KEY (id);


--
-- Name: com_post_category_masters com_post_category_masters_parent_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_category_masters
    ADD CONSTRAINT com_post_category_masters_parent_id_non_negative CHECK ((parent_id >= 0)) NOT VALID;


--
-- Name: com_post_category_masters com_post_category_masters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_category_masters
    ADD CONSTRAINT com_post_category_masters_pkey PRIMARY KEY (id);


--
-- Name: com_post_review_statuses com_post_review_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_review_statuses
    ADD CONSTRAINT com_post_review_statuses_pkey PRIMARY KEY (id);


--
-- Name: com_post_reviews com_post_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_reviews
    ADD CONSTRAINT com_post_reviews_pkey PRIMARY KEY (id);


--
-- Name: com_post_revisions com_post_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_revisions
    ADD CONSTRAINT com_post_revisions_pkey PRIMARY KEY (id);


--
-- Name: com_post_statuses com_post_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_statuses
    ADD CONSTRAINT com_post_statuses_pkey PRIMARY KEY (id);


--
-- Name: com_post_tag_masters com_post_tag_masters_parent_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_tag_masters
    ADD CONSTRAINT com_post_tag_masters_parent_id_non_negative CHECK ((parent_id >= 0)) NOT VALID;


--
-- Name: com_post_tag_masters com_post_tag_masters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_tag_masters
    ADD CONSTRAINT com_post_tag_masters_pkey PRIMARY KEY (id);


--
-- Name: com_post_tags com_post_tags_master_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.com_post_tags
    ADD CONSTRAINT com_post_tags_master_id_non_negative CHECK ((com_post_tag_master_id >= 0)) NOT VALID;


--
-- Name: com_post_tags com_post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_tags
    ADD CONSTRAINT com_post_tags_pkey PRIMARY KEY (id);


--
-- Name: com_post_versions com_post_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_versions
    ADD CONSTRAINT com_post_versions_pkey PRIMARY KEY (id);


--
-- Name: com_posts com_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_posts
    ADD CONSTRAINT com_posts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_com_post_categories_on_com_post_category_master_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_categories_on_com_post_category_master_id ON public.com_post_categories USING btree (com_post_category_master_id);


--
-- Name: index_com_post_categories_on_com_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_post_categories_on_com_post_id ON public.com_post_categories USING btree (com_post_id);


--
-- Name: index_com_post_category_masters_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_category_masters_on_parent_id ON public.com_post_category_masters USING btree (parent_id);


--
-- Name: index_com_post_reviews_on_com_post_id_and_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_post_reviews_on_com_post_id_and_reviewer_actor_id ON public.com_post_reviews USING btree (com_post_id, reviewer_actor_id);


--
-- Name: index_com_post_reviews_on_com_post_review_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_reviews_on_com_post_review_status_id ON public.com_post_reviews USING btree (com_post_review_status_id);


--
-- Name: index_com_post_reviews_on_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_reviews_on_reviewer_actor_id ON public.com_post_reviews USING btree (reviewer_actor_id) WHERE (decided_at IS NULL);


--
-- Name: index_com_post_revisions_on_com_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_revisions_on_com_post_id_and_created_at ON public.com_post_revisions USING btree (com_post_id, created_at DESC);


--
-- Name: index_com_post_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_post_revisions_on_public_id ON public.com_post_revisions USING btree (public_id);


--
-- Name: index_com_post_tag_masters_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_tag_masters_on_parent_id ON public.com_post_tag_masters USING btree (parent_id);


--
-- Name: index_com_post_tags_on_com_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_tags_on_com_post_id ON public.com_post_tags USING btree (com_post_id);


--
-- Name: index_com_post_tags_on_com_post_tag_master_id_and_com_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_post_tags_on_com_post_tag_master_id_and_com_post_id ON public.com_post_tags USING btree (com_post_tag_master_id, com_post_id);


--
-- Name: index_com_post_versions_on_com_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_post_versions_on_com_post_id_and_created_at ON public.com_post_versions USING btree (com_post_id, created_at DESC);


--
-- Name: index_com_post_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_post_versions_on_public_id ON public.com_post_versions USING btree (public_id);


--
-- Name: index_com_posts_on_author_avatar_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_posts_on_author_avatar_id_and_created_at ON public.com_posts USING btree (author_avatar_id, created_at DESC);


--
-- Name: index_com_posts_on_com_post_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_posts_on_com_post_status_id ON public.com_posts USING btree (com_post_status_id);


--
-- Name: index_com_posts_on_latest_com_post_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_posts_on_latest_com_post_revision_id ON public.com_posts USING btree (latest_com_post_revision_id);


--
-- Name: index_com_posts_on_latest_com_post_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_posts_on_latest_com_post_version_id ON public.com_posts USING btree (latest_com_post_version_id);


--
-- Name: index_com_posts_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_posts_on_permalink ON public.com_posts USING btree (permalink);


--
-- Name: index_com_posts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_com_posts_on_public_id ON public.com_posts USING btree (public_id);


--
-- Name: index_com_posts_on_published_at_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_com_posts_on_published_at_and_expires_at ON public.com_posts USING btree (published_at, expires_at);


--
-- Name: com_post_revisions fk_rails_05817f9198; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_revisions
    ADD CONSTRAINT fk_rails_05817f9198 FOREIGN KEY (com_post_id) REFERENCES public.com_posts(id) ON DELETE CASCADE;


--
-- Name: com_posts fk_rails_0c2fab94dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_posts
    ADD CONSTRAINT fk_rails_0c2fab94dc FOREIGN KEY (com_post_status_id) REFERENCES public.com_post_statuses(id);


--
-- Name: com_posts fk_rails_1aaba65180; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_posts
    ADD CONSTRAINT fk_rails_1aaba65180 FOREIGN KEY (latest_com_post_version_id) REFERENCES public.com_post_versions(id) ON DELETE SET NULL;


--
-- Name: com_post_categories fk_rails_1c8744edf5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_categories
    ADD CONSTRAINT fk_rails_1c8744edf5 FOREIGN KEY (com_post_id) REFERENCES public.com_posts(id) ON DELETE CASCADE;


--
-- Name: com_post_versions fk_rails_5f7c4b6bbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_versions
    ADD CONSTRAINT fk_rails_5f7c4b6bbb FOREIGN KEY (com_post_id) REFERENCES public.com_posts(id) ON DELETE CASCADE;


--
-- Name: com_posts fk_rails_69307c572d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_posts
    ADD CONSTRAINT fk_rails_69307c572d FOREIGN KEY (latest_com_post_revision_id) REFERENCES public.com_post_revisions(id) ON DELETE SET NULL;


--
-- Name: com_post_categories fk_rails_a677300bb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_categories
    ADD CONSTRAINT fk_rails_a677300bb6 FOREIGN KEY (com_post_category_master_id) REFERENCES public.com_post_category_masters(id);


--
-- Name: com_post_reviews fk_rails_cf21001c1d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_reviews
    ADD CONSTRAINT fk_rails_cf21001c1d FOREIGN KEY (com_post_id) REFERENCES public.com_posts(id);


--
-- Name: com_post_reviews fk_rails_db5004f1f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_reviews
    ADD CONSTRAINT fk_rails_db5004f1f7 FOREIGN KEY (com_post_review_status_id) REFERENCES public.com_post_review_statuses(id);


--
-- Name: com_post_tags fk_rails_e33f9a0083; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_tags
    ADD CONSTRAINT fk_rails_e33f9a0083 FOREIGN KEY (com_post_tag_master_id) REFERENCES public.com_post_tag_masters(id);


--
-- Name: com_post_tags fk_rails_fdf74b486b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.com_post_tags
    ADD CONSTRAINT fk_rails_fdf74b486b FOREIGN KEY (com_post_id) REFERENCES public.com_posts(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260530143000'),
('20260528162202'),
('20260525231100'),
('20260525231000');

