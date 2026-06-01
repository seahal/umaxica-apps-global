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
-- Name: org_post_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_categories (
    id bigint NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: org_post_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_categories_id_seq OWNED BY public.org_post_categories.id;


--
-- Name: org_post_categorizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_categorizations (
    id bigint NOT NULL,
    org_post_category_id bigint DEFAULT 0 NOT NULL,
    org_post_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_post_categorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_categorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_categorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_categorizations_id_seq OWNED BY public.org_post_categorizations.id;


--
-- Name: org_post_review_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_review_statuses (
    id bigint NOT NULL
);


--
-- Name: org_post_review_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_review_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_review_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_review_statuses_id_seq OWNED BY public.org_post_review_statuses.id;


--
-- Name: org_post_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_reviews (
    id bigint NOT NULL,
    comment text,
    decided_at timestamp with time zone,
    org_post_id bigint NOT NULL,
    org_post_review_status_id bigint NOT NULL,
    reviewer_actor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_post_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_reviews_id_seq OWNED BY public.org_post_reviews.id;


--
-- Name: org_post_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_revisions (
    id bigint NOT NULL,
    body text,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    org_post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_post_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_revisions_id_seq OWNED BY public.org_post_revisions.id;


--
-- Name: org_post_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_statuses (
    id bigint NOT NULL
);


--
-- Name: org_post_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_statuses_id_seq OWNED BY public.org_post_statuses.id;


--
-- Name: org_post_taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_taggings (
    id bigint NOT NULL,
    org_post_id bigint NOT NULL,
    org_post_tag_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_post_taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_taggings_id_seq OWNED BY public.org_post_taggings.id;


--
-- Name: org_post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_tags (
    id bigint NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: org_post_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_tags_id_seq OWNED BY public.org_post_tags.id;


--
-- Name: org_post_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_post_versions (
    id bigint NOT NULL,
    body text,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    org_post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: org_post_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_post_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_post_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_post_versions_id_seq OWNED BY public.org_post_versions.id;


--
-- Name: org_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_posts (
    id bigint NOT NULL,
    author_avatar_id bigint NOT NULL,
    body text NOT NULL,
    created_by_actor_id bigint NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    latest_org_post_revision_id bigint,
    latest_org_post_version_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    permalink character varying(200) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    org_post_status_id bigint NOT NULL,
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
-- Name: org_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.org_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: org_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.org_posts_id_seq OWNED BY public.org_posts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: org_post_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_categories ALTER COLUMN id SET DEFAULT nextval('public.org_post_categories_id_seq'::regclass);


--
-- Name: org_post_categorizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_categorizations ALTER COLUMN id SET DEFAULT nextval('public.org_post_categorizations_id_seq'::regclass);


--
-- Name: org_post_review_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_review_statuses ALTER COLUMN id SET DEFAULT nextval('public.org_post_review_statuses_id_seq'::regclass);


--
-- Name: org_post_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_reviews ALTER COLUMN id SET DEFAULT nextval('public.org_post_reviews_id_seq'::regclass);


--
-- Name: org_post_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_revisions ALTER COLUMN id SET DEFAULT nextval('public.org_post_revisions_id_seq'::regclass);


--
-- Name: org_post_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_statuses ALTER COLUMN id SET DEFAULT nextval('public.org_post_statuses_id_seq'::regclass);


--
-- Name: org_post_taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_taggings ALTER COLUMN id SET DEFAULT nextval('public.org_post_taggings_id_seq'::regclass);


--
-- Name: org_post_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_tags ALTER COLUMN id SET DEFAULT nextval('public.org_post_tags_id_seq'::regclass);


--
-- Name: org_post_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_versions ALTER COLUMN id SET DEFAULT nextval('public.org_post_versions_id_seq'::regclass);


--
-- Name: org_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_posts ALTER COLUMN id SET DEFAULT nextval('public.org_posts_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: org_post_revisions chk_org_post_revisions_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_revisions
    ADD CONSTRAINT chk_org_post_revisions_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: org_post_revisions chk_org_post_revisions_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_revisions
    ADD CONSTRAINT chk_org_post_revisions_response_mode CHECK (((response_mode)::text = ANY (ARRAY[('html'::character varying)::text, ('text'::character varying)::text, ('pdf'::character varying)::text, ('redirect'::character varying)::text]))) NOT VALID;


--
-- Name: org_post_versions chk_org_post_versions_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_versions
    ADD CONSTRAINT chk_org_post_versions_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: org_post_versions chk_org_post_versions_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_versions
    ADD CONSTRAINT chk_org_post_versions_response_mode CHECK (((response_mode)::text = ANY (ARRAY[('html'::character varying)::text, ('text'::character varying)::text, ('pdf'::character varying)::text, ('redirect'::character varying)::text]))) NOT VALID;


--
-- Name: org_posts chk_org_posts_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_posts
    ADD CONSTRAINT chk_org_posts_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: org_posts chk_org_posts_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_posts
    ADD CONSTRAINT chk_org_posts_response_mode CHECK (((response_mode)::text = ANY (ARRAY[('html'::character varying)::text, ('text'::character varying)::text, ('pdf'::character varying)::text, ('redirect'::character varying)::text]))) NOT VALID;


--
-- Name: org_post_categorizations org_post_categories_master_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_categorizations
    ADD CONSTRAINT org_post_categories_master_id_non_negative CHECK ((org_post_category_id >= 0)) NOT VALID;


--
-- Name: org_post_categories org_post_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_categories
    ADD CONSTRAINT org_post_categories_pkey PRIMARY KEY (id);


--
-- Name: org_post_categorizations org_post_categorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_categorizations
    ADD CONSTRAINT org_post_categorizations_pkey PRIMARY KEY (id);


--
-- Name: org_post_categories org_post_category_masters_parent_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_categories
    ADD CONSTRAINT org_post_category_masters_parent_id_non_negative CHECK ((parent_id >= 0)) NOT VALID;


--
-- Name: org_post_review_statuses org_post_review_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_review_statuses
    ADD CONSTRAINT org_post_review_statuses_pkey PRIMARY KEY (id);


--
-- Name: org_post_reviews org_post_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_reviews
    ADD CONSTRAINT org_post_reviews_pkey PRIMARY KEY (id);


--
-- Name: org_post_revisions org_post_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_revisions
    ADD CONSTRAINT org_post_revisions_pkey PRIMARY KEY (id);


--
-- Name: org_post_statuses org_post_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_statuses
    ADD CONSTRAINT org_post_statuses_pkey PRIMARY KEY (id);


--
-- Name: org_post_tags org_post_tag_masters_parent_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_tags
    ADD CONSTRAINT org_post_tag_masters_parent_id_non_negative CHECK ((parent_id >= 0)) NOT VALID;


--
-- Name: org_post_taggings org_post_taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_taggings
    ADD CONSTRAINT org_post_taggings_pkey PRIMARY KEY (id);


--
-- Name: org_post_taggings org_post_tags_master_id_non_negative; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.org_post_taggings
    ADD CONSTRAINT org_post_tags_master_id_non_negative CHECK ((org_post_tag_id >= 0)) NOT VALID;


--
-- Name: org_post_tags org_post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_tags
    ADD CONSTRAINT org_post_tags_pkey PRIMARY KEY (id);


--
-- Name: org_post_versions org_post_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_versions
    ADD CONSTRAINT org_post_versions_pkey PRIMARY KEY (id);


--
-- Name: org_posts org_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_posts
    ADD CONSTRAINT org_posts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_org_post_categories_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_categories_on_parent_id ON public.org_post_categories USING btree (parent_id);


--
-- Name: index_org_post_categorizations_on_org_post_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_categorizations_on_org_post_category_id ON public.org_post_categorizations USING btree (org_post_category_id);


--
-- Name: index_org_post_categorizations_on_org_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_post_categorizations_on_org_post_id ON public.org_post_categorizations USING btree (org_post_id);


--
-- Name: index_org_post_reviews_on_org_post_id_and_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_post_reviews_on_org_post_id_and_reviewer_actor_id ON public.org_post_reviews USING btree (org_post_id, reviewer_actor_id);


--
-- Name: index_org_post_reviews_on_org_post_review_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_reviews_on_org_post_review_status_id ON public.org_post_reviews USING btree (org_post_review_status_id);


--
-- Name: index_org_post_reviews_on_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_reviews_on_reviewer_actor_id ON public.org_post_reviews USING btree (reviewer_actor_id) WHERE (decided_at IS NULL);


--
-- Name: index_org_post_revisions_on_org_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_revisions_on_org_post_id_and_created_at ON public.org_post_revisions USING btree (org_post_id, created_at DESC);


--
-- Name: index_org_post_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_post_revisions_on_public_id ON public.org_post_revisions USING btree (public_id);


--
-- Name: index_org_post_taggings_on_org_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_taggings_on_org_post_id ON public.org_post_taggings USING btree (org_post_id);


--
-- Name: index_org_post_taggings_on_org_post_tag_id_and_org_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_post_taggings_on_org_post_tag_id_and_org_post_id ON public.org_post_taggings USING btree (org_post_tag_id, org_post_id);


--
-- Name: index_org_post_tags_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_tags_on_parent_id ON public.org_post_tags USING btree (parent_id);


--
-- Name: index_org_post_versions_on_org_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_post_versions_on_org_post_id_and_created_at ON public.org_post_versions USING btree (org_post_id, created_at DESC);


--
-- Name: index_org_post_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_post_versions_on_public_id ON public.org_post_versions USING btree (public_id);


--
-- Name: index_org_posts_on_author_avatar_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_posts_on_author_avatar_id_and_created_at ON public.org_posts USING btree (author_avatar_id, created_at DESC);


--
-- Name: index_org_posts_on_latest_org_post_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_posts_on_latest_org_post_revision_id ON public.org_posts USING btree (latest_org_post_revision_id);


--
-- Name: index_org_posts_on_latest_org_post_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_posts_on_latest_org_post_version_id ON public.org_posts USING btree (latest_org_post_version_id);


--
-- Name: index_org_posts_on_org_post_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_posts_on_org_post_status_id ON public.org_posts USING btree (org_post_status_id);


--
-- Name: index_org_posts_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_posts_on_permalink ON public.org_posts USING btree (permalink);


--
-- Name: index_org_posts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_org_posts_on_public_id ON public.org_posts USING btree (public_id);


--
-- Name: index_org_posts_on_published_at_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_org_posts_on_published_at_and_expires_at ON public.org_posts USING btree (published_at, expires_at);


--
-- Name: org_post_revisions fk_rails_05817f9198; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_revisions
    ADD CONSTRAINT fk_rails_05817f9198 FOREIGN KEY (org_post_id) REFERENCES public.org_posts(id) ON DELETE CASCADE;


--
-- Name: org_posts fk_rails_0c2fab94dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_posts
    ADD CONSTRAINT fk_rails_0c2fab94dc FOREIGN KEY (org_post_status_id) REFERENCES public.org_post_statuses(id);


--
-- Name: org_posts fk_rails_1aaba65180; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_posts
    ADD CONSTRAINT fk_rails_1aaba65180 FOREIGN KEY (latest_org_post_version_id) REFERENCES public.org_post_versions(id) ON DELETE SET NULL;


--
-- Name: org_post_categorizations fk_rails_1c8744edf5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_categorizations
    ADD CONSTRAINT fk_rails_1c8744edf5 FOREIGN KEY (org_post_id) REFERENCES public.org_posts(id) ON DELETE CASCADE;


--
-- Name: org_post_versions fk_rails_5f7c4b6bbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_versions
    ADD CONSTRAINT fk_rails_5f7c4b6bbb FOREIGN KEY (org_post_id) REFERENCES public.org_posts(id) ON DELETE CASCADE;


--
-- Name: org_posts fk_rails_69307c572d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_posts
    ADD CONSTRAINT fk_rails_69307c572d FOREIGN KEY (latest_org_post_revision_id) REFERENCES public.org_post_revisions(id) ON DELETE SET NULL;


--
-- Name: org_post_categorizations fk_rails_a677300bb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_categorizations
    ADD CONSTRAINT fk_rails_a677300bb6 FOREIGN KEY (org_post_category_id) REFERENCES public.org_post_categories(id);


--
-- Name: org_post_reviews fk_rails_cf21001c1d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_reviews
    ADD CONSTRAINT fk_rails_cf21001c1d FOREIGN KEY (org_post_id) REFERENCES public.org_posts(id);


--
-- Name: org_post_reviews fk_rails_db5004f1f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_reviews
    ADD CONSTRAINT fk_rails_db5004f1f7 FOREIGN KEY (org_post_review_status_id) REFERENCES public.org_post_review_statuses(id);


--
-- Name: org_post_taggings fk_rails_e33f9a0083; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_taggings
    ADD CONSTRAINT fk_rails_e33f9a0083 FOREIGN KEY (org_post_tag_id) REFERENCES public.org_post_tags(id);


--
-- Name: org_post_taggings fk_rails_fdf74b486b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_post_taggings
    ADD CONSTRAINT fk_rails_fdf74b486b FOREIGN KEY (org_post_id) REFERENCES public.org_posts(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260530143200'),
('20260530143100'),
('20260530143000'),
('20260528162201'),
('20260525231100'),
('20260525231000');

