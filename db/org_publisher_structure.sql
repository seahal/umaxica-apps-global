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
-- Name: post_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_categories (
    id bigint NOT NULL,
    post_category_master_id bigint DEFAULT 0 NOT NULL,
    post_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT post_categories_master_id_non_negative CHECK ((post_category_master_id >= 0))
);


--
-- Name: post_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_categories_id_seq OWNED BY public.post_categories.id;


--
-- Name: post_category_masters; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_category_masters (
    id bigint NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL,
    CONSTRAINT post_category_masters_parent_id_non_negative CHECK ((parent_id >= 0))
);


--
-- Name: post_category_masters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_category_masters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_category_masters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_category_masters_id_seq OWNED BY public.post_category_masters.id;


--
-- Name: post_review_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_review_statuses (
    id bigint NOT NULL
);


--
-- Name: post_review_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_review_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_review_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_review_statuses_id_seq OWNED BY public.post_review_statuses.id;


--
-- Name: post_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_reviews (
    id bigint NOT NULL,
    comment text,
    decided_at timestamp with time zone,
    post_id bigint NOT NULL,
    post_review_status_id bigint NOT NULL,
    reviewer_actor_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: post_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_reviews_id_seq OWNED BY public.post_reviews.id;


--
-- Name: post_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_revisions (
    id bigint NOT NULL,
    body text,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: post_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_revisions_id_seq OWNED BY public.post_revisions.id;


--
-- Name: post_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_statuses (
    id bigint NOT NULL
);


--
-- Name: post_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_statuses_id_seq OWNED BY public.post_statuses.id;


--
-- Name: post_tag_masters; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_tag_masters (
    id bigint NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL,
    CONSTRAINT post_tag_masters_parent_id_non_negative CHECK ((parent_id >= 0))
);


--
-- Name: post_tag_masters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_tag_masters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tag_masters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_tag_masters_id_seq OWNED BY public.post_tag_masters.id;


--
-- Name: post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_tags (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    post_tag_master_id bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT post_tags_master_id_non_negative CHECK ((post_tag_master_id >= 0))
);


--
-- Name: post_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_tags_id_seq OWNED BY public.post_tags.id;


--
-- Name: post_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.post_versions (
    id bigint NOT NULL,
    body text,
    description character varying,
    edited_by_id bigint,
    edited_by_type character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    permalink character varying(200) NOT NULL,
    post_id bigint NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    publish_at timestamp(6) with time zone NOT NULL,
    redirect_url character varying,
    response_mode character varying NOT NULL,
    title character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: post_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.post_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_versions_id_seq OWNED BY public.post_versions.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.posts (
    id bigint NOT NULL,
    author_avatar_id bigint NOT NULL,
    body text NOT NULL,
    created_by_actor_id bigint NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    latest_revision_id bigint,
    latest_version_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    permalink character varying(200) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    post_status_id bigint NOT NULL,
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
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: post_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories ALTER COLUMN id SET DEFAULT nextval('public.post_categories_id_seq'::regclass);


--
-- Name: post_category_masters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_category_masters ALTER COLUMN id SET DEFAULT nextval('public.post_category_masters_id_seq'::regclass);


--
-- Name: post_review_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_review_statuses ALTER COLUMN id SET DEFAULT nextval('public.post_review_statuses_id_seq'::regclass);


--
-- Name: post_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews ALTER COLUMN id SET DEFAULT nextval('public.post_reviews_id_seq'::regclass);


--
-- Name: post_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_revisions ALTER COLUMN id SET DEFAULT nextval('public.post_revisions_id_seq'::regclass);


--
-- Name: post_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_statuses ALTER COLUMN id SET DEFAULT nextval('public.post_statuses_id_seq'::regclass);


--
-- Name: post_tag_masters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tag_masters ALTER COLUMN id SET DEFAULT nextval('public.post_tag_masters_id_seq'::regclass);


--
-- Name: post_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags ALTER COLUMN id SET DEFAULT nextval('public.post_tags_id_seq'::regclass);


--
-- Name: post_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions ALTER COLUMN id SET DEFAULT nextval('public.post_versions_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: post_revisions chk_post_revisions_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.post_revisions
    ADD CONSTRAINT chk_post_revisions_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: post_revisions chk_post_revisions_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.post_revisions
    ADD CONSTRAINT chk_post_revisions_response_mode CHECK (((response_mode)::text = ANY ((ARRAY['html'::character varying, 'text'::character varying, 'pdf'::character varying, 'redirect'::character varying])::text[]))) NOT VALID;


--
-- Name: post_versions chk_post_versions_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.post_versions
    ADD CONSTRAINT chk_post_versions_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: post_versions chk_post_versions_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.post_versions
    ADD CONSTRAINT chk_post_versions_response_mode CHECK (((response_mode)::text = ANY ((ARRAY['html'::character varying, 'text'::character varying, 'pdf'::character varying, 'redirect'::character varying])::text[]))) NOT VALID;


--
-- Name: posts chk_posts_redirect_url_for_redirect; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.posts
    ADD CONSTRAINT chk_posts_redirect_url_for_redirect CHECK ((((response_mode)::text <> 'redirect'::text) OR (redirect_url IS NOT NULL))) NOT VALID;


--
-- Name: posts chk_posts_response_mode; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.posts
    ADD CONSTRAINT chk_posts_response_mode CHECK (((response_mode)::text = ANY ((ARRAY['html'::character varying, 'text'::character varying, 'pdf'::character varying, 'redirect'::character varying])::text[]))) NOT VALID;


--
-- Name: post_categories post_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories
    ADD CONSTRAINT post_categories_pkey PRIMARY KEY (id);


--
-- Name: post_category_masters post_category_masters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_category_masters
    ADD CONSTRAINT post_category_masters_pkey PRIMARY KEY (id);


--
-- Name: post_review_statuses post_review_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_review_statuses
    ADD CONSTRAINT post_review_statuses_pkey PRIMARY KEY (id);


--
-- Name: post_reviews post_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews
    ADD CONSTRAINT post_reviews_pkey PRIMARY KEY (id);


--
-- Name: post_revisions post_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_revisions
    ADD CONSTRAINT post_revisions_pkey PRIMARY KEY (id);


--
-- Name: post_statuses post_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_statuses
    ADD CONSTRAINT post_statuses_pkey PRIMARY KEY (id);


--
-- Name: post_tag_masters post_tag_masters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tag_masters
    ADD CONSTRAINT post_tag_masters_pkey PRIMARY KEY (id);


--
-- Name: post_tags post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_pkey PRIMARY KEY (id);


--
-- Name: post_versions post_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT post_versions_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_post_categories_on_post_category_master_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_categories_on_post_category_master_id ON public.post_categories USING btree (post_category_master_id);


--
-- Name: index_post_categories_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_categories_on_post_id ON public.post_categories USING btree (post_id);


--
-- Name: index_post_category_masters_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_category_masters_on_parent_id ON public.post_category_masters USING btree (parent_id);


--
-- Name: index_post_reviews_on_post_id_and_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_reviews_on_post_id_and_reviewer_actor_id ON public.post_reviews USING btree (post_id, reviewer_actor_id);


--
-- Name: index_post_reviews_on_post_review_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_reviews_on_post_review_status_id ON public.post_reviews USING btree (post_review_status_id);


--
-- Name: index_post_reviews_on_reviewer_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_reviews_on_reviewer_actor_id ON public.post_reviews USING btree (reviewer_actor_id) WHERE (decided_at IS NULL);


--
-- Name: index_post_revisions_on_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_revisions_on_post_id_and_created_at ON public.post_revisions USING btree (post_id, created_at DESC);


--
-- Name: index_post_revisions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_revisions_on_public_id ON public.post_revisions USING btree (public_id);


--
-- Name: index_post_tag_masters_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_tag_masters_on_parent_id ON public.post_tag_masters USING btree (parent_id);


--
-- Name: index_post_tags_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_tags_on_post_id ON public.post_tags USING btree (post_id);


--
-- Name: index_post_tags_on_post_tag_master_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_tags_on_post_tag_master_id_and_post_id ON public.post_tags USING btree (post_tag_master_id, post_id);


--
-- Name: index_post_versions_on_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_versions_on_post_id_and_created_at ON public.post_versions USING btree (post_id, created_at DESC);


--
-- Name: index_post_versions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_versions_on_public_id ON public.post_versions USING btree (public_id);


--
-- Name: index_posts_on_author_avatar_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_author_avatar_id_and_created_at ON public.posts USING btree (author_avatar_id, created_at DESC);


--
-- Name: index_posts_on_latest_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_latest_revision_id ON public.posts USING btree (latest_revision_id);


--
-- Name: index_posts_on_latest_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_latest_version_id ON public.posts USING btree (latest_version_id);


--
-- Name: index_posts_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_permalink ON public.posts USING btree (permalink);


--
-- Name: index_posts_on_post_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_post_status_id ON public.posts USING btree (post_status_id);


--
-- Name: index_posts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_public_id ON public.posts USING btree (public_id);


--
-- Name: index_posts_on_published_at_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_published_at_and_expires_at ON public.posts USING btree (published_at, expires_at);


--
-- Name: post_revisions fk_rails_05817f9198; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_revisions
    ADD CONSTRAINT fk_rails_05817f9198 FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts fk_rails_0c2fab94dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_0c2fab94dc FOREIGN KEY (post_status_id) REFERENCES public.post_statuses(id);


--
-- Name: posts fk_rails_1aaba65180; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_1aaba65180 FOREIGN KEY (latest_version_id) REFERENCES public.post_versions(id) ON DELETE SET NULL;


--
-- Name: post_categories fk_rails_1c8744edf5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories
    ADD CONSTRAINT fk_rails_1c8744edf5 FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_versions fk_rails_5f7c4b6bbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT fk_rails_5f7c4b6bbb FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts fk_rails_69307c572d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_69307c572d FOREIGN KEY (latest_revision_id) REFERENCES public.post_revisions(id) ON DELETE SET NULL;


--
-- Name: post_categories fk_rails_a677300bb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories
    ADD CONSTRAINT fk_rails_a677300bb6 FOREIGN KEY (post_category_master_id) REFERENCES public.post_category_masters(id);


--
-- Name: post_reviews fk_rails_cf21001c1d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews
    ADD CONSTRAINT fk_rails_cf21001c1d FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: post_reviews fk_rails_db5004f1f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reviews
    ADD CONSTRAINT fk_rails_db5004f1f7 FOREIGN KEY (post_review_status_id) REFERENCES public.post_review_statuses(id);


--
-- Name: post_tags fk_rails_e33f9a0083; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT fk_rails_e33f9a0083 FOREIGN KEY (post_tag_master_id) REFERENCES public.post_tag_masters(id);


--
-- Name: post_tags fk_rails_fdf74b486b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT fk_rails_fdf74b486b FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260528162201'),
('20260525231100'),
('20260525231000');

