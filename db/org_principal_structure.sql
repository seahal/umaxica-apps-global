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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: check_staff_identity_emails_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_staff_identity_emails_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE emails_count integer; BEGIN IF NEW.staff_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO emails_count FROM staff_identity_emails WHERE staff_id = NEW.staff_id; IF emails_count >= 4 THEN RAISE EXCEPTION 'staff_identity_emails limit (4) exceeded for staff %', NEW.staff_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_staff_identity_passkeys_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_staff_identity_passkeys_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE passkeys_count integer; BEGIN SELECT COUNT(*) INTO passkeys_count FROM staff_identity_passkeys WHERE staff_id = NEW.staff_id; IF passkeys_count >= 4 THEN RAISE EXCEPTION 'staff_identity_passkeys limit (4) exceeded for staff %', NEW.staff_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_staff_identity_telephones_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_staff_identity_telephones_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE telephones_count integer; BEGIN IF NEW.staff_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO telephones_count FROM staff_identity_telephones WHERE staff_id = NEW.staff_id; IF telephones_count >= 4 THEN RAISE EXCEPTION 'staff_identity_telephones limit (4) exceeded for staff %', NEW.staff_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


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
-- Name: department_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.department_statuses (
    id bigint NOT NULL
);


--
-- Name: department_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.department_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: department_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.department_statuses_id_seq OWNED BY public.department_statuses.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.departments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    workspace_id bigint,
    parent_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    department_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: division_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.division_statuses (
    id bigint NOT NULL
);


--
-- Name: division_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.division_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: division_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.division_statuses_id_seq OWNED BY public.division_statuses.id;


--
-- Name: divisions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.divisions (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    organization_id bigint NOT NULL,
    division_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: divisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.divisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: divisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.divisions_id_seq OWNED BY public.divisions.id;


--
-- Name: operator_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_accounts (
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
-- Name: operator_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_accounts_id_seq
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
-- Name: operator_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_banners (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    published boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT staff_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: operator_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_banners_id_seq OWNED BY public.operator_banners.id;


--
-- Name: operator_bulletins; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_bulletins (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    title character varying NOT NULL,
    body text,
    read_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_bulletins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_bulletins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_bulletins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_bulletins_id_seq OWNED BY public.operator_bulletins.id;


--
-- Name: operator_email_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_email_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_email_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_email_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_email_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_email_statuses_id_seq OWNED BY public.operator_email_statuses.id;


--
-- Name: operator_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_emails (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    address character varying NOT NULL,
    otp_private_key character varying NOT NULL,
    otp_counter text NOT NULL,
    otp_expires_at timestamp(6) with time zone,
    otp_last_sent_at timestamp(6) with time zone,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_email_status_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    undeletable boolean DEFAULT false NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    address_digest character varying
);


--
-- Name: operator_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_emails_id_seq OWNED BY public.operator_emails.id;


--
-- Name: operator_identity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_identity_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_identity_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_identity_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_identity_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_identity_statuses_id_seq OWNED BY public.operator_identity_statuses.id;


--
-- Name: operator_lifecycle_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_lifecycle_requests (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    action character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    target_operator_id bigint,
    target_email character varying,
    organization_id bigint,
    role_id bigint DEFAULT 0 NOT NULL,
    requested_by_operator_id bigint NOT NULL,
    approved_by_operator_id bigint,
    rejected_by_operator_id bigint,
    executed_by_operator_id bigint,
    invitation_id bigint,
    reason text,
    rejection_reason text,
    approved_at timestamp(6) with time zone,
    rejected_at timestamp(6) with time zone,
    executed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_lifecycle_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_lifecycle_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_lifecycle_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_lifecycle_requests_id_seq OWNED BY public.operator_lifecycle_requests.id;


--
-- Name: operator_multi_factor_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_multi_factor_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_multi_factor_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_multi_factor_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_multi_factor_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_multi_factor_statuses_id_seq OWNED BY public.operator_multi_factor_statuses.id;


--
-- Name: operator_multi_factors; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_multi_factors (
    id bigint NOT NULL
);


--
-- Name: operator_multi_factors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_multi_factors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_multi_factors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_multi_factors_id_seq OWNED BY public.operator_multi_factors.id;


--
-- Name: operator_passkey_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_passkey_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_passkey_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_passkey_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_passkey_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_passkey_statuses_id_seq OWNED BY public.operator_passkey_statuses.id;


--
-- Name: operator_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_passkeys (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    external_id character varying NOT NULL,
    public_key text NOT NULL,
    sign_count integer NOT NULL,
    user_handle character varying,
    name character varying NOT NULL,
    transports character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 0 NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    last_used_at timestamp(6) with time zone
);


--
-- Name: operator_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_passkeys_id_seq OWNED BY public.operator_passkeys.id;


--
-- Name: operator_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_currencies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_currencies_id_seq OWNED BY public.operator_preference_currencies.id;


--
-- Name: operator_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_currency_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_currency_options_id_seq OWNED BY public.operator_preference_currency_options.id;


--
-- Name: operator_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_date_format_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_date_format_options_id_seq OWNED BY public.operator_preference_date_format_options.id;


--
-- Name: operator_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_date_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_date_formats_id_seq OWNED BY public.operator_preference_date_formats.id;


--
-- Name: operator_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_densities (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_densities_id_seq OWNED BY public.operator_preference_densities.id;


--
-- Name: operator_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_density_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_density_options_id_seq OWNED BY public.operator_preference_density_options.id;


--
-- Name: operator_preference_items_per_page_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_items_per_page_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_items_per_page_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_items_per_page_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_items_per_page_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_items_per_page_options_id_seq OWNED BY public.operator_preference_items_per_page_options.id;


--
-- Name: operator_preference_items_per_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_items_per_pages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_items_per_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_items_per_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_items_per_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_items_per_pages_id_seq OWNED BY public.operator_preference_items_per_pages.id;


--
-- Name: operator_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_language_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_language_options_id_seq OWNED BY public.operator_preference_language_options.id;


--
-- Name: operator_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_languages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_languages_id_seq OWNED BY public.operator_preference_languages.id;


--
-- Name: operator_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_motion_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_motion_options_id_seq OWNED BY public.operator_preference_motion_options.id;


--
-- Name: operator_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_motions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_motions_id_seq OWNED BY public.operator_preference_motions.id;


--
-- Name: operator_preference_r18_display_stopper_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_r18_display_stopper_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_r18_display_stopper_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_r18_display_stopper_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_r18_display_stopper_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_r18_display_stopper_options_id_seq OWNED BY public.operator_preference_r18_display_stopper_options.id;


--
-- Name: operator_preference_r18_display_stoppers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_r18_display_stoppers (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_r18_display_stoppers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_r18_display_stoppers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_r18_display_stoppers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_r18_display_stoppers_id_seq OWNED BY public.operator_preference_r18_display_stoppers.id;


--
-- Name: operator_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_region_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_region_options_id_seq OWNED BY public.operator_preference_region_options.id;


--
-- Name: operator_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_regions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_regions_id_seq OWNED BY public.operator_preference_regions.id;


--
-- Name: operator_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_theme_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_theme_options_id_seq OWNED BY public.operator_preference_theme_options.id;


--
-- Name: operator_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_themes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_themes_id_seq OWNED BY public.operator_preference_themes.id;


--
-- Name: operator_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_time_format_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_time_format_options_id_seq OWNED BY public.operator_preference_time_format_options.id;


--
-- Name: operator_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_time_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_time_formats_id_seq OWNED BY public.operator_preference_time_formats.id;


--
-- Name: operator_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_timezone_options (
    id bigint NOT NULL
);


--
-- Name: operator_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_timezone_options_id_seq OWNED BY public.operator_preference_timezone_options.id;


--
-- Name: operator_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preference_timezones (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preference_timezones_id_seq OWNED BY public.operator_preference_timezones.id;


--
-- Name: operator_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_preferences (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    consented boolean DEFAULT false NOT NULL,
    functional boolean DEFAULT false NOT NULL,
    performant boolean DEFAULT false NOT NULL,
    targetable boolean DEFAULT false NOT NULL,
    consented_at timestamp(6) with time zone,
    consent_version uuid,
    language character varying DEFAULT 'ja'::character varying NOT NULL,
    region character varying DEFAULT 'jp'::character varying NOT NULL,
    timezone character varying DEFAULT 'Asia/Tokyo'::character varying NOT NULL,
    theme character varying DEFAULT 'sy'::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(21),
    currency character varying DEFAULT 'jpy'::character varying NOT NULL,
    date_format character varying DEFAULT 'iso'::character varying NOT NULL,
    time_format character varying DEFAULT 'hour_24'::character varying NOT NULL,
    motion character varying DEFAULT 'standard'::character varying NOT NULL,
    density character varying DEFAULT 'standard'::character varying NOT NULL,
    items_per_page character varying DEFAULT '20'::character varying NOT NULL
);


--
-- Name: operator_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_preferences_id_seq OWNED BY public.operator_preferences.id;


--
-- Name: operator_secret_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_secret_kinds (
    id bigint NOT NULL
);


--
-- Name: operator_secret_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_secret_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secret_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secret_kinds_id_seq OWNED BY public.operator_secret_kinds.id;


--
-- Name: operator_secret_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_secret_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_secret_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_secret_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secret_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secret_statuses_id_seq OWNED BY public.operator_secret_statuses.id;


--
-- Name: operator_secrets; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_secrets (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    password_digest character varying,
    last_used_at timestamp(6) with time zone,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_secret_status_id bigint DEFAULT 0 NOT NULL,
    staff_secret_kind_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_staff_secrets_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: operator_secrets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_secrets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_secrets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_secrets_id_seq OWNED BY public.operator_secrets.id;


--
-- Name: operator_social_google_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_social_google_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_social_google_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_social_google_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_social_google_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_social_google_statuses_id_seq OWNED BY public.operator_social_google_statuses.id;


--
-- Name: operator_social_googles; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_social_googles (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    provider character varying DEFAULT 'google_org'::character varying NOT NULL,
    uid character varying DEFAULT ''::character varying NOT NULL,
    token character varying DEFAULT ''::character varying NOT NULL,
    refresh_token character varying DEFAULT ''::character varying NOT NULL,
    token_expires_at integer NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: operator_social_googles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_social_googles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_social_googles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_social_googles_id_seq OWNED BY public.operator_social_googles.id;


--
-- Name: operator_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_statuses_id_seq OWNED BY public.operator_statuses.id;


--
-- Name: operator_telephone_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_telephone_statuses (
    id bigint NOT NULL
);


--
-- Name: operator_telephone_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_telephone_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_telephone_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_telephone_statuses_id_seq OWNED BY public.operator_telephone_statuses.id;


--
-- Name: operator_telephones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_telephones (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    number character varying NOT NULL,
    otp_private_key character varying NOT NULL,
    otp_counter text NOT NULL,
    otp_expires_at timestamp(6) with time zone,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    staff_identity_telephone_status_id bigint DEFAULT 0 NOT NULL,
    number_digest character varying
);


--
-- Name: operator_telephones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_telephones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_telephones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_telephones_id_seq OWNED BY public.operator_telephones.id;


--
-- Name: operator_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operator_visibilities (
    id bigint NOT NULL
);


--
-- Name: operator_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operator_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_visibilities_id_seq OWNED BY public.operator_visibilities.id;


--
-- Name: operators; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.operators (
    id bigint NOT NULL,
    webauthn_id character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    public_id character varying(16) NOT NULL,
    withdrawn_at timestamp(6) with time zone,
    status_id bigint DEFAULT 0 NOT NULL,
    multi_factor_enabled boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    visibility_id bigint DEFAULT 2 NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    multi_factor_id bigint DEFAULT 0 NOT NULL,
    multi_factor_status_id bigint DEFAULT 5 NOT NULL,
    withdrawal_started_at timestamp(6) with time zone,
    deactivated_at timestamp(6) with time zone,
    birthdate text,
    CONSTRAINT chk_operators_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000))),
    CONSTRAINT chk_staffs_public_id_format CHECK (((public_id)::text ~ '^[0-9A-FGHJKMNPQRSTVWXYZ]{16}$'::text)),
    CONSTRAINT chk_staffs_public_id_length CHECK ((char_length((public_id)::text) = 16)),
    CONSTRAINT chk_staffs_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: operators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.operators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operators_id_seq OWNED BY public.operators.id;


--
-- Name: organization_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.organization_statuses (
    id bigint NOT NULL
);


--
-- Name: organization_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.organization_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organization_statuses_id_seq OWNED BY public.organization_statuses.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.organizations (
    id bigint NOT NULL,
    domain character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    operator_id bigint,
    department_id bigint,
    parent_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    workspace_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.role_assignments (
    id bigint NOT NULL,
    user_id bigint,
    staff_id bigint,
    role_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: role_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.role_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: role_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.role_assignments_id_seq OWNED BY public.role_assignments.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: staff_identity_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.staff_identity_audit_events (
    id character varying NOT NULL
);


--
-- Name: staff_identity_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.staff_identity_audits (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    event_id character varying NOT NULL,
    "timestamp" timestamp(6) with time zone,
    ip_address character varying,
    actor_id bigint,
    actor_type character varying,
    previous_value text,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_identity_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.staff_identity_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_identity_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_identity_audits_id_seq OWNED BY public.staff_identity_audits.id;


--
-- Name: staff_identity_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.staff_identity_passkeys (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    webauthn_id bytea NOT NULL,
    public_key text NOT NULL,
    description character varying NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    external_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_identity_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.staff_identity_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_identity_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_identity_passkeys_id_seq OWNED BY public.staff_identity_passkeys.id;


--
-- Name: staff_identity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.staff_identity_statuses (
    id bigint NOT NULL
);


--
-- Name: staff_identity_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.staff_identity_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_identity_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_identity_statuses_id_seq OWNED BY public.staff_identity_statuses.id;


--
-- Name: staff_operators; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.staff_operators (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    operator_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_operators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.staff_operators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_operators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_operators_id_seq OWNED BY public.staff_operators.id;


--
-- Name: staff_recovery_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.staff_recovery_codes (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    recovery_code_digest character varying,
    expires_in date,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: staff_recovery_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.staff_recovery_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_recovery_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_recovery_codes_id_seq OWNED BY public.staff_recovery_codes.id;


--
-- Name: user_workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.user_workspaces (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: user_workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.user_workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_workspaces_id_seq OWNED BY public.user_workspaces.id;


--
-- Name: workspace_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.workspace_statuses (
    id bigint NOT NULL
);


--
-- Name: workspace_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.workspace_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspace_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspace_statuses_id_seq OWNED BY public.workspace_statuses.id;


--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.workspaces (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspaces_id_seq OWNED BY public.workspaces.id;


--
-- Name: department_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department_statuses ALTER COLUMN id SET DEFAULT nextval('public.department_statuses_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: division_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.division_statuses ALTER COLUMN id SET DEFAULT nextval('public.division_statuses_id_seq'::regclass);


--
-- Name: divisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions ALTER COLUMN id SET DEFAULT nextval('public.divisions_id_seq'::regclass);


--
-- Name: operator_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts ALTER COLUMN id SET DEFAULT nextval('public.operator_accounts_id_seq'::regclass);


--
-- Name: operator_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_banners ALTER COLUMN id SET DEFAULT nextval('public.operator_banners_id_seq'::regclass);


--
-- Name: operator_bulletins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_bulletins ALTER COLUMN id SET DEFAULT nextval('public.operator_bulletins_id_seq'::regclass);


--
-- Name: operator_email_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_email_statuses_id_seq'::regclass);


--
-- Name: operator_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails ALTER COLUMN id SET DEFAULT nextval('public.operator_emails_id_seq'::regclass);


--
-- Name: operator_identity_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identity_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_identity_statuses_id_seq'::regclass);


--
-- Name: operator_lifecycle_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_lifecycle_requests ALTER COLUMN id SET DEFAULT nextval('public.operator_lifecycle_requests_id_seq'::regclass);


--
-- Name: operator_multi_factor_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_multi_factor_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_multi_factor_statuses_id_seq'::regclass);


--
-- Name: operator_multi_factors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_multi_factors ALTER COLUMN id SET DEFAULT nextval('public.operator_multi_factors_id_seq'::regclass);


--
-- Name: operator_passkey_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_passkey_statuses_id_seq'::regclass);


--
-- Name: operator_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys ALTER COLUMN id SET DEFAULT nextval('public.operator_passkeys_id_seq'::regclass);


--
-- Name: operator_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_currencies_id_seq'::regclass);


--
-- Name: operator_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_currency_options_id_seq'::regclass);


--
-- Name: operator_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_date_format_options_id_seq'::regclass);


--
-- Name: operator_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_date_formats_id_seq'::regclass);


--
-- Name: operator_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_densities_id_seq'::regclass);


--
-- Name: operator_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_density_options_id_seq'::regclass);


--
-- Name: operator_preference_items_per_page_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_items_per_page_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_items_per_page_options_id_seq'::regclass);


--
-- Name: operator_preference_items_per_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_items_per_pages ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_items_per_pages_id_seq'::regclass);


--
-- Name: operator_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_language_options_id_seq'::regclass);


--
-- Name: operator_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_languages_id_seq'::regclass);


--
-- Name: operator_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_motion_options_id_seq'::regclass);


--
-- Name: operator_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_motions_id_seq'::regclass);


--
-- Name: operator_preference_r18_display_stopper_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_r18_display_stopper_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_r18_display_stopper_options_id_seq'::regclass);


--
-- Name: operator_preference_r18_display_stoppers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_r18_display_stoppers ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_r18_display_stoppers_id_seq'::regclass);


--
-- Name: operator_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_region_options_id_seq'::regclass);


--
-- Name: operator_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_regions_id_seq'::regclass);


--
-- Name: operator_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_theme_options_id_seq'::regclass);


--
-- Name: operator_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_themes_id_seq'::regclass);


--
-- Name: operator_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_time_format_options_id_seq'::regclass);


--
-- Name: operator_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_time_formats_id_seq'::regclass);


--
-- Name: operator_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_timezone_options_id_seq'::regclass);


--
-- Name: operator_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.operator_preference_timezones_id_seq'::regclass);


--
-- Name: operator_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preferences ALTER COLUMN id SET DEFAULT nextval('public.operator_preferences_id_seq'::regclass);


--
-- Name: operator_secret_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_kinds ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_kinds_id_seq'::regclass);


--
-- Name: operator_secret_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_secret_statuses_id_seq'::regclass);


--
-- Name: operator_secrets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secrets ALTER COLUMN id SET DEFAULT nextval('public.operator_secrets_id_seq'::regclass);


--
-- Name: operator_social_google_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_social_google_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_social_google_statuses_id_seq'::regclass);


--
-- Name: operator_social_googles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_social_googles ALTER COLUMN id SET DEFAULT nextval('public.operator_social_googles_id_seq'::regclass);


--
-- Name: operator_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_statuses_id_seq'::regclass);


--
-- Name: operator_telephone_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_statuses ALTER COLUMN id SET DEFAULT nextval('public.operator_telephone_statuses_id_seq'::regclass);


--
-- Name: operator_telephones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones ALTER COLUMN id SET DEFAULT nextval('public.operator_telephones_id_seq'::regclass);


--
-- Name: operator_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visibilities ALTER COLUMN id SET DEFAULT nextval('public.operator_visibilities_id_seq'::regclass);


--
-- Name: operators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators ALTER COLUMN id SET DEFAULT nextval('public.operators_id_seq'::regclass);


--
-- Name: organization_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_statuses ALTER COLUMN id SET DEFAULT nextval('public.organization_statuses_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: role_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments ALTER COLUMN id SET DEFAULT nextval('public.role_assignments_id_seq'::regclass);


--
-- Name: staff_identity_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits ALTER COLUMN id SET DEFAULT nextval('public.staff_identity_audits_id_seq'::regclass);


--
-- Name: staff_identity_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_passkeys ALTER COLUMN id SET DEFAULT nextval('public.staff_identity_passkeys_id_seq'::regclass);


--
-- Name: staff_identity_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_statuses ALTER COLUMN id SET DEFAULT nextval('public.staff_identity_statuses_id_seq'::regclass);


--
-- Name: staff_operators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators ALTER COLUMN id SET DEFAULT nextval('public.staff_operators_id_seq'::regclass);


--
-- Name: staff_recovery_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_recovery_codes ALTER COLUMN id SET DEFAULT nextval('public.staff_recovery_codes_id_seq'::regclass);


--
-- Name: user_workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_workspaces ALTER COLUMN id SET DEFAULT nextval('public.user_workspaces_id_seq'::regclass);


--
-- Name: workspace_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_statuses ALTER COLUMN id SET DEFAULT nextval('public.workspace_statuses_id_seq'::regclass);


--
-- Name: workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces ALTER COLUMN id SET DEFAULT nextval('public.workspaces_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: operators chk_operators_mfa_requirement_consistency; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operators
    ADD CONSTRAINT chk_operators_mfa_requirement_consistency CHECK ((((multi_factor_enabled = false) AND (multi_factor_id = 0)) OR ((multi_factor_enabled = true) AND (multi_factor_id <> 0)))) NOT VALID;


--
-- Name: operators chk_operators_withdrawal_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.operators
    ADD CONSTRAINT chk_operators_withdrawal_order CHECK (((withdrawal_started_at IS NULL) OR (withdrawn_at IS NULL) OR (withdrawal_started_at <= withdrawn_at))) NOT VALID;


--
-- Name: department_statuses department_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.department_statuses
    ADD CONSTRAINT department_statuses_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: division_statuses division_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.division_statuses
    ADD CONSTRAINT division_statuses_pkey PRIMARY KEY (id);


--
-- Name: divisions divisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT divisions_pkey PRIMARY KEY (id);


--
-- Name: operator_accounts operator_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts
    ADD CONSTRAINT operator_accounts_pkey PRIMARY KEY (id);


--
-- Name: operator_banners operator_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_banners
    ADD CONSTRAINT operator_banners_pkey PRIMARY KEY (id);


--
-- Name: operator_bulletins operator_bulletins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_bulletins
    ADD CONSTRAINT operator_bulletins_pkey PRIMARY KEY (id);


--
-- Name: operator_email_statuses operator_email_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_email_statuses
    ADD CONSTRAINT operator_email_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_emails operator_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT operator_emails_pkey PRIMARY KEY (id);


--
-- Name: operator_identity_statuses operator_identity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_identity_statuses
    ADD CONSTRAINT operator_identity_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_lifecycle_requests operator_lifecycle_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_lifecycle_requests
    ADD CONSTRAINT operator_lifecycle_requests_pkey PRIMARY KEY (id);


--
-- Name: operator_multi_factor_statuses operator_multi_factor_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_multi_factor_statuses
    ADD CONSTRAINT operator_multi_factor_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_multi_factors operator_multi_factors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_multi_factors
    ADD CONSTRAINT operator_multi_factors_pkey PRIMARY KEY (id);


--
-- Name: operator_passkey_statuses operator_passkey_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkey_statuses
    ADD CONSTRAINT operator_passkey_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_passkeys operator_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT operator_passkeys_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_currencies operator_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies
    ADD CONSTRAINT operator_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_currency_options operator_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currency_options
    ADD CONSTRAINT operator_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_date_format_options operator_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_format_options
    ADD CONSTRAINT operator_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_date_formats operator_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats
    ADD CONSTRAINT operator_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_densities operator_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities
    ADD CONSTRAINT operator_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_density_options operator_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_density_options
    ADD CONSTRAINT operator_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_items_per_page_options operator_preference_items_per_page_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_items_per_page_options
    ADD CONSTRAINT operator_preference_items_per_page_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_items_per_pages operator_preference_items_per_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_items_per_pages
    ADD CONSTRAINT operator_preference_items_per_pages_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_language_options operator_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_language_options
    ADD CONSTRAINT operator_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_languages operator_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages
    ADD CONSTRAINT operator_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_motion_options operator_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motion_options
    ADD CONSTRAINT operator_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_motions operator_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions
    ADD CONSTRAINT operator_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_r18_display_stopper_options operator_preference_r18_display_stopper_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_r18_display_stopper_options
    ADD CONSTRAINT operator_preference_r18_display_stopper_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_r18_display_stoppers operator_preference_r18_display_stoppers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_r18_display_stoppers
    ADD CONSTRAINT operator_preference_r18_display_stoppers_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_region_options operator_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_region_options
    ADD CONSTRAINT operator_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_regions operator_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions
    ADD CONSTRAINT operator_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_theme_options operator_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_theme_options
    ADD CONSTRAINT operator_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_themes operator_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes
    ADD CONSTRAINT operator_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_time_format_options operator_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_format_options
    ADD CONSTRAINT operator_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_time_formats operator_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats
    ADD CONSTRAINT operator_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_timezone_options operator_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezone_options
    ADD CONSTRAINT operator_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: operator_preference_timezones operator_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones
    ADD CONSTRAINT operator_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: operator_preferences operator_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preferences
    ADD CONSTRAINT operator_preferences_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_kinds operator_secret_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_kinds
    ADD CONSTRAINT operator_secret_kinds_pkey PRIMARY KEY (id);


--
-- Name: operator_secret_statuses operator_secret_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secret_statuses
    ADD CONSTRAINT operator_secret_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_secrets operator_secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secrets
    ADD CONSTRAINT operator_secrets_pkey PRIMARY KEY (id);


--
-- Name: operator_social_google_statuses operator_social_google_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_social_google_statuses
    ADD CONSTRAINT operator_social_google_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_social_googles operator_social_googles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_social_googles
    ADD CONSTRAINT operator_social_googles_pkey PRIMARY KEY (id);


--
-- Name: operator_statuses operator_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_statuses
    ADD CONSTRAINT operator_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_telephone_statuses operator_telephone_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephone_statuses
    ADD CONSTRAINT operator_telephone_statuses_pkey PRIMARY KEY (id);


--
-- Name: operator_telephones operator_telephones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT operator_telephones_pkey PRIMARY KEY (id);


--
-- Name: operator_visibilities operator_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_visibilities
    ADD CONSTRAINT operator_visibilities_pkey PRIMARY KEY (id);


--
-- Name: operators operators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT operators_pkey PRIMARY KEY (id);


--
-- Name: organization_statuses organization_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization_statuses
    ADD CONSTRAINT organization_statuses_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: staff_identity_audit_events staff_identity_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audit_events
    ADD CONSTRAINT staff_identity_audit_events_pkey PRIMARY KEY (id);


--
-- Name: staff_identity_audits staff_identity_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits
    ADD CONSTRAINT staff_identity_audits_pkey PRIMARY KEY (id);


--
-- Name: staff_identity_passkeys staff_identity_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_passkeys
    ADD CONSTRAINT staff_identity_passkeys_pkey PRIMARY KEY (id);


--
-- Name: staff_identity_statuses staff_identity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_statuses
    ADD CONSTRAINT staff_identity_statuses_pkey PRIMARY KEY (id);


--
-- Name: staff_operators staff_operators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators
    ADD CONSTRAINT staff_operators_pkey PRIMARY KEY (id);


--
-- Name: staff_recovery_codes staff_recovery_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_recovery_codes
    ADD CONSTRAINT staff_recovery_codes_pkey PRIMARY KEY (id);


--
-- Name: user_workspaces user_workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_workspaces
    ADD CONSTRAINT user_workspaces_pkey PRIMARY KEY (id);


--
-- Name: workspace_statuses workspace_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_statuses
    ADD CONSTRAINT workspace_statuses_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: idx_on_preference_id_7d925420d9; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_preference_id_7d925420d9 ON public.operator_preference_r18_display_stoppers USING btree (preference_id);


--
-- Name: idx_on_staff_identity_telephone_status_id_6c01767c57; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_staff_identity_telephone_status_id_6c01767c57 ON public.operator_telephones USING btree (staff_identity_telephone_status_id);


--
-- Name: index_departments_on_department_status_id_and_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departments_on_department_status_id_and_parent_id ON public.departments USING btree (department_status_id, parent_id);


--
-- Name: index_departments_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_parent_id ON public.departments USING btree (parent_id);


--
-- Name: index_departments_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_workspace_id ON public.departments USING btree (workspace_id);


--
-- Name: index_divisions_on_division_status_id_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_divisions_on_division_status_id_and_organization_id ON public.divisions USING btree (division_status_id, organization_id);


--
-- Name: index_divisions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_divisions_on_organization_id ON public.divisions USING btree (organization_id);


--
-- Name: index_operator_accounts_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_accounts_on_department_id ON public.operator_accounts USING btree (department_id);


--
-- Name: index_operator_accounts_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_accounts_on_public_id ON public.operator_accounts USING btree (public_id);


--
-- Name: index_operator_accounts_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_accounts_on_staff_id ON public.operator_accounts USING btree (staff_id);


--
-- Name: index_operator_accounts_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_accounts_on_status_id ON public.operator_accounts USING btree (status_id);


--
-- Name: index_operator_banners_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_banners_on_staff_id ON public.operator_banners USING btree (staff_id);


--
-- Name: index_operator_bulletins_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_bulletins_on_public_id ON public.operator_bulletins USING btree (public_id);


--
-- Name: index_operator_bulletins_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_bulletins_on_staff_id ON public.operator_bulletins USING btree (staff_id);


--
-- Name: index_operator_emails_on_address_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_emails_on_address_digest ON public.operator_emails USING btree (address_digest) WHERE (address_digest IS NOT NULL);


--
-- Name: index_operator_emails_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_emails_on_public_id ON public.operator_emails USING btree (public_id);


--
-- Name: index_operator_emails_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_emails_on_staff_id ON public.operator_emails USING btree (staff_id);


--
-- Name: index_operator_emails_on_staff_identity_email_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_emails_on_staff_identity_email_status_id ON public.operator_emails USING btree (staff_identity_email_status_id);


--
-- Name: index_operator_lifecycle_requests_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_action ON public.operator_lifecycle_requests USING btree (action);


--
-- Name: index_operator_lifecycle_requests_on_approved_by_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_approved_by_operator_id ON public.operator_lifecycle_requests USING btree (approved_by_operator_id);


--
-- Name: index_operator_lifecycle_requests_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_lifecycle_requests_on_public_id ON public.operator_lifecycle_requests USING btree (public_id);


--
-- Name: index_operator_lifecycle_requests_on_requested_by_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_requested_by_operator_id ON public.operator_lifecycle_requests USING btree (requested_by_operator_id);


--
-- Name: index_operator_lifecycle_requests_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_status ON public.operator_lifecycle_requests USING btree (status);


--
-- Name: index_operator_lifecycle_requests_on_target_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_target_email ON public.operator_lifecycle_requests USING btree (target_email);


--
-- Name: index_operator_lifecycle_requests_on_target_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_lifecycle_requests_on_target_operator_id ON public.operator_lifecycle_requests USING btree (target_operator_id);


--
-- Name: index_operator_passkeys_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkeys_on_external_id ON public.operator_passkeys USING btree (external_id);


--
-- Name: index_operator_passkeys_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkeys_on_staff_id ON public.operator_passkeys USING btree (staff_id);


--
-- Name: index_operator_passkeys_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_passkeys_on_status_id ON public.operator_passkeys USING btree (status_id);


--
-- Name: index_operator_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_passkeys_on_webauthn_id ON public.operator_passkeys USING btree (webauthn_id);


--
-- Name: index_operator_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_currencies_on_option_id ON public.operator_preference_currencies USING btree (option_id);


--
-- Name: index_operator_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_currencies_on_preference_id ON public.operator_preference_currencies USING btree (preference_id);


--
-- Name: index_operator_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_date_formats_on_option_id ON public.operator_preference_date_formats USING btree (option_id);


--
-- Name: index_operator_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_date_formats_on_preference_id ON public.operator_preference_date_formats USING btree (preference_id);


--
-- Name: index_operator_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_densities_on_option_id ON public.operator_preference_densities USING btree (option_id);


--
-- Name: index_operator_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_densities_on_preference_id ON public.operator_preference_densities USING btree (preference_id);


--
-- Name: index_operator_preference_items_per_pages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_items_per_pages_on_option_id ON public.operator_preference_items_per_pages USING btree (option_id);


--
-- Name: index_operator_preference_items_per_pages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_items_per_pages_on_preference_id ON public.operator_preference_items_per_pages USING btree (preference_id);


--
-- Name: index_operator_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_languages_on_option_id ON public.operator_preference_languages USING btree (option_id);


--
-- Name: index_operator_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_languages_on_preference_id ON public.operator_preference_languages USING btree (preference_id);


--
-- Name: index_operator_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_motions_on_option_id ON public.operator_preference_motions USING btree (option_id);


--
-- Name: index_operator_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_motions_on_preference_id ON public.operator_preference_motions USING btree (preference_id);


--
-- Name: index_operator_preference_r18_display_stoppers_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_r18_display_stoppers_on_option_id ON public.operator_preference_r18_display_stoppers USING btree (option_id);


--
-- Name: index_operator_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_regions_on_option_id ON public.operator_preference_regions USING btree (option_id);


--
-- Name: index_operator_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_regions_on_preference_id ON public.operator_preference_regions USING btree (preference_id);


--
-- Name: index_operator_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_themes_on_option_id ON public.operator_preference_themes USING btree (option_id);


--
-- Name: index_operator_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_themes_on_preference_id ON public.operator_preference_themes USING btree (preference_id);


--
-- Name: index_operator_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_time_formats_on_option_id ON public.operator_preference_time_formats USING btree (option_id);


--
-- Name: index_operator_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_time_formats_on_preference_id ON public.operator_preference_time_formats USING btree (preference_id);


--
-- Name: index_operator_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_preference_timezones_on_option_id ON public.operator_preference_timezones USING btree (option_id);


--
-- Name: index_operator_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preference_timezones_on_preference_id ON public.operator_preference_timezones USING btree (preference_id);


--
-- Name: index_operator_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preferences_on_public_id ON public.operator_preferences USING btree (public_id);


--
-- Name: index_operator_preferences_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_preferences_on_staff_id ON public.operator_preferences USING btree (staff_id);


--
-- Name: index_operator_secrets_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_secrets_on_public_id ON public.operator_secrets USING btree (public_id);


--
-- Name: index_operator_secrets_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_secrets_on_staff_id ON public.operator_secrets USING btree (staff_id);


--
-- Name: index_operator_secrets_on_staff_identity_secret_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_secrets_on_staff_identity_secret_status_id ON public.operator_secrets USING btree (staff_identity_secret_status_id);


--
-- Name: index_operator_secrets_on_staff_secret_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_secrets_on_staff_secret_kind_id ON public.operator_secrets USING btree (staff_secret_kind_id);


--
-- Name: index_operator_social_googles_on_staff_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_social_googles_on_staff_id_unique ON public.operator_social_googles USING btree (staff_id) WHERE (staff_id IS NOT NULL);


--
-- Name: index_operator_social_googles_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_social_googles_on_status_id ON public.operator_social_googles USING btree (status_id);


--
-- Name: index_operator_social_googles_on_token_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_social_googles_on_token_expires_at ON public.operator_social_googles USING btree (token_expires_at);


--
-- Name: index_operator_social_googles_on_uid_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_social_googles_on_uid_and_provider ON public.operator_social_googles USING btree (uid, provider);


--
-- Name: index_operator_telephones_on_number_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operator_telephones_on_number_digest ON public.operator_telephones USING btree (number_digest) WHERE (number_digest IS NOT NULL);


--
-- Name: index_operator_telephones_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operator_telephones_on_staff_id ON public.operator_telephones USING btree (staff_id);


--
-- Name: index_operators_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_deactivated_at ON public.operators USING btree (deactivated_at) WHERE (deactivated_at IS NOT NULL);


--
-- Name: index_operators_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_discarded_at ON public.operators USING btree (discarded_at);


--
-- Name: index_operators_on_multi_factor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_multi_factor_id ON public.operators USING btree (multi_factor_id);


--
-- Name: index_operators_on_multi_factor_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_multi_factor_status_id ON public.operators USING btree (multi_factor_status_id);


--
-- Name: index_operators_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_operators_on_public_id ON public.operators USING btree (public_id);


--
-- Name: index_operators_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_purged_at ON public.operators USING btree (purged_at);


--
-- Name: index_operators_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_status_id ON public.operators USING btree (status_id);


--
-- Name: index_operators_on_visibility_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_visibility_id ON public.operators USING btree (visibility_id);


--
-- Name: index_operators_on_withdrawal_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_withdrawal_started_at ON public.operators USING btree (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL);


--
-- Name: index_operators_on_withdrawn_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_operators_on_withdrawn_at ON public.operators USING btree (withdrawn_at) WHERE (withdrawn_at IS NOT NULL);


--
-- Name: index_organizations_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_department_id ON public.organizations USING btree (department_id);


--
-- Name: index_organizations_on_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_domain ON public.organizations USING btree (domain);


--
-- Name: index_organizations_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_operator_id ON public.organizations USING btree (operator_id);


--
-- Name: index_organizations_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_parent_id ON public.organizations USING btree (parent_id);


--
-- Name: index_organizations_on_workspace_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_workspace_status_id ON public.organizations USING btree (workspace_status_id);


--
-- Name: index_role_assignments_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_role_id ON public.role_assignments USING btree (role_id);


--
-- Name: index_role_assignments_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_staff_id ON public.role_assignments USING btree (staff_id);


--
-- Name: index_role_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_user_id ON public.role_assignments USING btree (user_id);


--
-- Name: index_staff_identity_audits_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_identity_audits_on_staff_id ON public.staff_identity_audits USING btree (staff_id);


--
-- Name: index_staff_identity_passkeys_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_identity_passkeys_on_staff_id ON public.staff_identity_passkeys USING btree (staff_id);


--
-- Name: index_staff_identity_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_identity_passkeys_on_webauthn_id ON public.staff_identity_passkeys USING btree (webauthn_id);


--
-- Name: index_staff_operators_on_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_operators_on_operator_id ON public.staff_operators USING btree (operator_id);


--
-- Name: index_staff_operators_on_staff_id_and_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_operators_on_staff_id_and_operator_id ON public.staff_operators USING btree (staff_id, operator_id);


--
-- Name: index_staff_recovery_codes_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_recovery_codes_on_staff_id ON public.staff_recovery_codes USING btree (staff_id);


--
-- Name: index_user_workspaces_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_workspaces_on_user_id ON public.user_workspaces USING btree (user_id);


--
-- Name: index_user_workspaces_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_workspaces_on_workspace_id ON public.user_workspaces USING btree (workspace_id);


--
-- Name: departments fk_departments_on_department_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_departments_on_department_status_id FOREIGN KEY (department_status_id) REFERENCES public.department_statuses(id);


--
-- Name: staff_recovery_codes fk_rails_02267b87b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_recovery_codes
    ADD CONSTRAINT fk_rails_02267b87b9 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_densities fk_rails_11379cd530; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities
    ADD CONSTRAINT fk_rails_11379cd530 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_banners fk_rails_12bf867cd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_banners
    ADD CONSTRAINT fk_rails_12bf867cd7 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_secrets fk_rails_2386c20852; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secrets
    ADD CONSTRAINT fk_rails_2386c20852 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_items_per_pages fk_rails_2b838843e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_items_per_pages
    ADD CONSTRAINT fk_rails_2b838843e1 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_accounts fk_rails_326fe73dec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts
    ADD CONSTRAINT fk_rails_326fe73dec FOREIGN KEY (status_id) REFERENCES public.operator_statuses(id);


--
-- Name: operator_preference_time_formats fk_rails_3308cb70a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats
    ADD CONSTRAINT fk_rails_3308cb70a8 FOREIGN KEY (option_id) REFERENCES public.operator_preference_time_format_options(id);


--
-- Name: operator_preference_motions fk_rails_364d1205de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions
    ADD CONSTRAINT fk_rails_364d1205de FOREIGN KEY (option_id) REFERENCES public.operator_preference_motion_options(id);


--
-- Name: staff_identity_audits fk_rails_37d8b99dd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits
    ADD CONSTRAINT fk_rails_37d8b99dd1 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_date_formats fk_rails_3a3eaf6cd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats
    ADD CONSTRAINT fk_rails_3a3eaf6cd5 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_bulletins fk_rails_447185451c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_bulletins
    ADD CONSTRAINT fk_rails_447185451c FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: role_assignments fk_rails_4572e29aaa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_4572e29aaa FOREIGN KEY (staff_id) REFERENCES public.operators(id) ON DELETE CASCADE;


--
-- Name: operator_passkeys fk_rails_45b43df39a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT fk_rails_45b43df39a FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: staff_operators fk_rails_4701fc0635; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators
    ADD CONSTRAINT fk_rails_4701fc0635 FOREIGN KEY (operator_id) REFERENCES public.operator_accounts(id) ON DELETE CASCADE;


--
-- Name: operator_accounts fk_rails_4d1b310c86; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts
    ADD CONSTRAINT fk_rails_4d1b310c86 FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: operator_telephones fk_rails_52c0d3ae3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT fk_rails_52c0d3ae3b FOREIGN KEY (staff_identity_telephone_status_id) REFERENCES public.operator_telephone_statuses(id);


--
-- Name: operators fk_rails_5525188c4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_5525188c4e FOREIGN KEY (status_id) REFERENCES public.operator_identity_statuses(id);


--
-- Name: departments fk_rails_61e60f394e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_61e60f394e FOREIGN KEY (workspace_id) REFERENCES public.organizations(id) ON DELETE SET NULL;


--
-- Name: operators fk_rails_64606abff9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_64606abff9 FOREIGN KEY (visibility_id) REFERENCES public.operator_visibilities(id);


--
-- Name: divisions fk_rails_648c512956; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT fk_rails_648c512956 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: staff_identity_passkeys fk_rails_6a3a38c0e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_passkeys
    ADD CONSTRAINT fk_rails_6a3a38c0e0 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_accounts fk_rails_6ec07db706; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_accounts
    ADD CONSTRAINT fk_rails_6ec07db706 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_motions fk_rails_706f69bad6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_motions
    ADD CONSTRAINT fk_rails_706f69bad6 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operators fk_rails_894ffe7965; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_894ffe7965 FOREIGN KEY (multi_factor_id) REFERENCES public.operator_multi_factors(id);


--
-- Name: organizations fk_rails_8ca3ef141d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_rails_8ca3ef141d FOREIGN KEY (workspace_status_id) REFERENCES public.organization_statuses(id);


--
-- Name: departments fk_rails_8e1e5764fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_8e1e5764fc FOREIGN KEY (parent_id) REFERENCES public.departments(id);


--
-- Name: operator_preference_time_formats fk_rails_8e89db7603; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_time_formats
    ADD CONSTRAINT fk_rails_8e89db7603 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_secrets fk_rails_8f8aed461a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secrets
    ADD CONSTRAINT fk_rails_8f8aed461a FOREIGN KEY (staff_identity_secret_status_id) REFERENCES public.operator_secret_statuses(id);


--
-- Name: operator_preference_r18_display_stoppers fk_rails_939f6081bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_r18_display_stoppers
    ADD CONSTRAINT fk_rails_939f6081bd FOREIGN KEY (option_id) REFERENCES public.operator_preference_r18_display_stopper_options(id);


--
-- Name: user_workspaces fk_rails_93a47871ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_workspaces
    ADD CONSTRAINT fk_rails_93a47871ac FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: operator_preferences fk_rails_9b2a21cc23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preferences
    ADD CONSTRAINT fk_rails_9b2a21cc23 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_densities fk_rails_aa06cb648f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_densities
    ADD CONSTRAINT fk_rails_aa06cb648f FOREIGN KEY (option_id) REFERENCES public.operator_preference_density_options(id);


--
-- Name: operator_emails fk_rails_b0310624d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT fk_rails_b0310624d3 FOREIGN KEY (staff_identity_email_status_id) REFERENCES public.operator_email_statuses(id);


--
-- Name: operator_passkeys fk_rails_b17ae8dc5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_passkeys
    ADD CONSTRAINT fk_rails_b17ae8dc5f FOREIGN KEY (status_id) REFERENCES public.operator_passkey_statuses(id);


--
-- Name: operator_social_googles fk_rails_b2b4364acf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_social_googles
    ADD CONSTRAINT fk_rails_b2b4364acf FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: operator_preference_date_formats fk_rails_c106156372; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_date_formats
    ADD CONSTRAINT fk_rails_c106156372 FOREIGN KEY (option_id) REFERENCES public.operator_preference_date_format_options(id);


--
-- Name: operator_preference_currencies fk_rails_c2649c3bf6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies
    ADD CONSTRAINT fk_rails_c2649c3bf6 FOREIGN KEY (option_id) REFERENCES public.operator_preference_currency_options(id);


--
-- Name: staff_operators fk_rails_cab1284f5e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_operators
    ADD CONSTRAINT fk_rails_cab1284f5e FOREIGN KEY (staff_id) REFERENCES public.operators(id) ON DELETE CASCADE;


--
-- Name: operator_emails fk_rails_cceb4b91db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_emails
    ADD CONSTRAINT fk_rails_cceb4b91db FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: staff_identity_audits fk_rails_ce4872192d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_identity_audits
    ADD CONSTRAINT fk_rails_ce4872192d FOREIGN KEY (event_id) REFERENCES public.staff_identity_audit_events(id);


--
-- Name: operators fk_rails_cfd2f37948; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operators
    ADD CONSTRAINT fk_rails_cfd2f37948 FOREIGN KEY (multi_factor_status_id) REFERENCES public.operator_multi_factor_statuses(id);


--
-- Name: operator_preference_r18_display_stoppers fk_rails_d26854a062; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_r18_display_stoppers
    ADD CONSTRAINT fk_rails_d26854a062 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_items_per_pages fk_rails_d9a9bd2617; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_items_per_pages
    ADD CONSTRAINT fk_rails_d9a9bd2617 FOREIGN KEY (option_id) REFERENCES public.operator_preference_items_per_page_options(id);


--
-- Name: operator_social_googles fk_rails_db81b40794; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_social_googles
    ADD CONSTRAINT fk_rails_db81b40794 FOREIGN KEY (status_id) REFERENCES public.operator_social_google_statuses(id);


--
-- Name: operator_telephones fk_rails_e5ae4ba106; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_telephones
    ADD CONSTRAINT fk_rails_e5ae4ba106 FOREIGN KEY (staff_id) REFERENCES public.operators(id);


--
-- Name: divisions fk_rails_eec18b8ece; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.divisions
    ADD CONSTRAINT fk_rails_eec18b8ece FOREIGN KEY (division_status_id) REFERENCES public.division_statuses(id);


--
-- Name: operator_preference_currencies fk_rails_f0cfc52f69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_currencies
    ADD CONSTRAINT fk_rails_f0cfc52f69 FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_languages fk_staff_preference_languages_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages
    ADD CONSTRAINT fk_staff_preference_languages_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_language_options(id);


--
-- Name: operator_preference_languages fk_staff_preference_languages_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_languages
    ADD CONSTRAINT fk_staff_preference_languages_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_regions fk_staff_preference_regions_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions
    ADD CONSTRAINT fk_staff_preference_regions_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_region_options(id);


--
-- Name: operator_preference_regions fk_staff_preference_regions_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_regions
    ADD CONSTRAINT fk_staff_preference_regions_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_themes fk_staff_preference_themes_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes
    ADD CONSTRAINT fk_staff_preference_themes_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_theme_options(id);


--
-- Name: operator_preference_themes fk_staff_preference_themes_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_themes
    ADD CONSTRAINT fk_staff_preference_themes_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_preference_timezones fk_staff_preference_timezones_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones
    ADD CONSTRAINT fk_staff_preference_timezones_on_option_id FOREIGN KEY (option_id) REFERENCES public.operator_preference_timezone_options(id);


--
-- Name: operator_preference_timezones fk_staff_preference_timezones_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_preference_timezones
    ADD CONSTRAINT fk_staff_preference_timezones_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.operator_preferences(id);


--
-- Name: operator_secrets fk_staff_secrets_on_staff_secret_kind_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operator_secrets
    ADD CONSTRAINT fk_staff_secrets_on_staff_secret_kind_id FOREIGN KEY (staff_secret_kind_id) REFERENCES public.operator_secret_kinds(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260528162001'),
('20260526090000'),
('20260521120000'),
('20260520193000'),
('20260520143008'),
('20260518181000'),
('20260518180000'),
('20260518170001'),
('20260518170000'),
('20260518163000'),
('20260518130001'),
('20260518130000'),
('20260514153000'),
('20260514143000'),
('20260514140000'),
('20260514113000'),
('20260514100000'),
('20260513161000'),
('20260512111000'),
('20260512103100'),
('20260509120000'),
('20260508160000'),
('20260508151000'),
('20260508140999'),
('20260508140931'),
('20260508135006'),
('20260507000006'),
('20260507000005'),
('20260507000004'),
('20260507000003'),
('20260507000001'),
('20260506210800'),
('20260506020000'),
('20260329151000'),
('20260329084522'),
('20260323013709'),
('20260323000000'),
('20260319125136'),
('20260318035440'),
('20260312120000'),
('20260311130000'),
('20260311120000'),
('20260309000001'),
('20260307121000'),
('20260305000000'),
('20260226150001'),
('20260226130001'),
('20260213150001'),
('20260212000003'),
('20260210100000'),
('20260208193100'),
('20260208180001'),
('20260205150000'),
('20260204170001'),
('20260204120000'),
('20260203172000'),
('20260202260000'),
('20260202250000'),
('20260202230000'),
('20260202220000'),
('20260202210000'),
('20260202200301'),
('20260202200100'),
('20260202200000'),
('20260202170000'),
('20260201214320'),
('20260201210002'),
('20260201200004'),
('20260201200003'),
('20260201200002'),
('20260201190010'),
('20260130130001'),
('20260122130001'),
('20260122130000'),
('20260121195628'),
('20260121184600'),
('20260121141943'),
('20260121141942'),
('20260121141941'),
('20260121141859'),
('20260121083251'),
('20260121083249'),
('20260121083247'),
('20260114120236'),
('20260110194100'),
('20260109141212'),
('20260108100600'),
('20260106120001'),
('20260106110001'),
('20260103133001'),
('20260103133000'),
('20260103122221'),
('20260103122100'),
('20260103120000'),
('20260103062756'),
('20260103054521'),
('20260103054520'),
('20260103053821'),
('20260103053820'),
('20260103053811'),
('20260103053810'),
('20260103053759'),
('20260103053507'),
('20260103053506'),
('20260103052010'),
('20260103050111'),
('20260103050110'),
('20260103050101'),
('20260103050100'),
('20260102100036'),
('20260102100035'),
('20260102035351'),
('20260102035129'),
('20260102035128'),
('20260102035007'),
('20260102034918'),
('20260102034859'),
('20260102034858'),
('20260102034808'),
('20260102030400'),
('20260102030339'),
('20260102030316'),
('20260102030012'),
('20260102025820'),
('20260102025200'),
('20251230170007'),
('20251230170004'),
('20251230150020'),
('20251230150000'),
('20251230145339'),
('20251230145324'),
('20251230140828'),
('20251230133000'),
('20251230103825'),
('20251230092048'),
('20251230092046'),
('20251230090000'),
('20251230080020'),
('20251230072241'),
('20251230072240'),
('20251230072230'),
('20251230045000'),
('20251230020000'),
('20251230010101'),
('20251228000005'),
('20251226020999'),
('20251226013001'),
('20251226000000'),
('20251225213915'),
('20251225183100'),
('20251224190000'),
('20251224173429'),
('20251224173001'),
('20251224172001'),
('20251224165000'),
('20251224164001'),
('20251224162001'),
('20251224161001'),
('20251224155900'),
('20251224154200'),
('20251224152200'),
('20251224140100'),
('20251224130000'),
('20251224123200'),
('20251224122000'),
('20251222215659'),
('20251222212001'),
('20251221133000'),
('20251221121101'),
('20251221121100'),
('20251221121000'),
('20251220091500'),
('20251218130512'),
('20251218130511'),
('20251218130510'),
('20251214134055'),
('20251213160234'),
('20251213154735'),
('20251213153924'),
('20251212163548'),
('20251212163541'),
('20251212163540'),
('20251211170001'),
('20251211164122'),
('20251211164106'),
('20251211164051'),
('20251211164035'),
('20251211090000'),
('20251211075547'),
('20251211075546'),
('20251209143000'),
('20251209133000'),
('20251209020000'),
('20251209014634'),
('20251208230200'),
('20251208230132'),
('20251208223235'),
('20251208211240'),
('20251208210549'),
('20251208054612'),
('20251115083000'),
('20251115082000'),
('20251115073000'),
('20251115071000'),
('20251115060000'),
('20250808064848'),
('20250801193449'),
('20250504005603'),
('20250429234634'),
('20250429231841'),
('20240827130202');

