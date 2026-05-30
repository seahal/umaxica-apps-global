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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_push_native_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.action_push_native_devices (
    id bigint NOT NULL,
    name character varying,
    platform character varying NOT NULL,
    token character varying NOT NULL,
    owner_type character varying,
    owner_id bigint,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: action_push_native_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.action_push_native_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_push_native_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_push_native_devices_id_seq OWNED BY public.action_push_native_devices.id;


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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: visitor_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_banners (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    published boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT visitor_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: visitor_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_banners_id_seq OWNED BY public.visitor_banners.id;


--
-- Name: visitor_email_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_email_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_email_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_email_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_email_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_email_statuses_id_seq OWNED BY public.visitor_email_statuses.id;


--
-- Name: visitor_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_emails (
    id bigint NOT NULL,
    address character varying DEFAULT ''::character varying NOT NULL,
    address_digest character varying,
    locked_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_last_sent_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    undeletable boolean DEFAULT false NOT NULL,
    verification_token_digest bytea,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_email_status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: visitor_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_emails_id_seq OWNED BY public.visitor_emails.id;


--
-- Name: visitor_mfa_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_mfa_levels (
    id bigint NOT NULL
);


--
-- Name: visitor_mfa_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_mfa_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_mfa_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_mfa_levels_id_seq OWNED BY public.visitor_mfa_levels.id;


--
-- Name: visitor_mfa_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_mfa_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_mfa_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_mfa_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_mfa_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_mfa_statuses_id_seq OWNED BY public.visitor_mfa_statuses.id;


--
-- Name: visitor_passkey_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_passkey_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_passkey_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_passkey_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_passkey_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_passkey_statuses_id_seq OWNED BY public.visitor_passkey_statuses.id;


--
-- Name: visitor_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_passkeys (
    id bigint NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    external_id uuid NOT NULL,
    last_used_at timestamp(6) with time zone,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    visitor_id bigint NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: visitor_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_passkeys_id_seq OWNED BY public.visitor_passkeys.id;


--
-- Name: visitor_preference_adult_content_gate_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_adult_content_gate_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_adult_content_gate_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_adult_content_gate_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_adult_content_gate_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_adult_content_gate_options_id_seq OWNED BY public.visitor_preference_adult_content_gate_options.id;


--
-- Name: visitor_preference_adult_content_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_adult_content_gates (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_adult_content_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_adult_content_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_adult_content_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_adult_content_gates_id_seq OWNED BY public.visitor_preference_adult_content_gates.id;


--
-- Name: visitor_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_currencies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_currencies_id_seq OWNED BY public.visitor_preference_currencies.id;


--
-- Name: visitor_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_currency_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_currency_options_id_seq OWNED BY public.visitor_preference_currency_options.id;


--
-- Name: visitor_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_date_format_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_date_format_options_id_seq OWNED BY public.visitor_preference_date_format_options.id;


--
-- Name: visitor_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_date_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_date_formats_id_seq OWNED BY public.visitor_preference_date_formats.id;


--
-- Name: visitor_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_densities (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_densities_id_seq OWNED BY public.visitor_preference_densities.id;


--
-- Name: visitor_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_density_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_density_options_id_seq OWNED BY public.visitor_preference_density_options.id;


--
-- Name: visitor_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_language_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_language_options_id_seq OWNED BY public.visitor_preference_language_options.id;


--
-- Name: visitor_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_languages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_languages_id_seq OWNED BY public.visitor_preference_languages.id;


--
-- Name: visitor_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_motion_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_motion_options_id_seq OWNED BY public.visitor_preference_motion_options.id;


--
-- Name: visitor_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_motions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_motions_id_seq OWNED BY public.visitor_preference_motions.id;


--
-- Name: visitor_preference_page_size_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_page_size_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_page_size_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_page_size_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_page_size_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_page_size_options_id_seq OWNED BY public.visitor_preference_page_size_options.id;


--
-- Name: visitor_preference_page_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_page_sizes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_page_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_page_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_page_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_page_sizes_id_seq OWNED BY public.visitor_preference_page_sizes.id;


--
-- Name: visitor_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_region_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_region_options_id_seq OWNED BY public.visitor_preference_region_options.id;


--
-- Name: visitor_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_regions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_regions_id_seq OWNED BY public.visitor_preference_regions.id;


--
-- Name: visitor_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_theme_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_theme_options_id_seq OWNED BY public.visitor_preference_theme_options.id;


--
-- Name: visitor_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_themes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_themes_id_seq OWNED BY public.visitor_preference_themes.id;


--
-- Name: visitor_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_time_format_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_time_format_options_id_seq OWNED BY public.visitor_preference_time_format_options.id;


--
-- Name: visitor_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_time_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_time_formats_id_seq OWNED BY public.visitor_preference_time_formats.id;


--
-- Name: visitor_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_timezone_options (
    id bigint NOT NULL
);


--
-- Name: visitor_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_timezone_options_id_seq OWNED BY public.visitor_preference_timezone_options.id;


--
-- Name: visitor_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preference_timezones (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preference_timezones_id_seq OWNED BY public.visitor_preference_timezones.id;


--
-- Name: visitor_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_preferences (
    id bigint NOT NULL,
    visitor_id bigint NOT NULL,
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
    currency character varying DEFAULT 'jpy'::character varying NOT NULL,
    date_format character varying DEFAULT 'iso'::character varying NOT NULL,
    time_format character varying DEFAULT 'hour_24'::character varying NOT NULL,
    motion character varying DEFAULT 'standard'::character varying NOT NULL,
    density character varying DEFAULT 'standard'::character varying NOT NULL,
    page_size character varying DEFAULT '20'::character varying NOT NULL,
    public_id character varying(21),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_preferences_id_seq OWNED BY public.visitor_preferences.id;


--
-- Name: visitor_secret_credential_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credential_kinds (
    id bigint NOT NULL
);


--
-- Name: visitor_secret_credential_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credential_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credential_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credential_kinds_id_seq OWNED BY public.visitor_secret_credential_kinds.id;


--
-- Name: visitor_secret_credential_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credential_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_secret_credential_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credential_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credential_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credential_statuses_id_seq OWNED BY public.visitor_secret_credential_statuses.id;


--
-- Name: visitor_secret_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_secret_credentials (
    id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    password_digest character varying DEFAULT ''::character varying NOT NULL,
    last_used_at timestamp(6) with time zone,
    uses_remaining integer DEFAULT 1 NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_secret_credential_status_id bigint DEFAULT 1 NOT NULL,
    visitor_secret_credential_kind_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_customer_secrets_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: visitor_secret_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_secret_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_secret_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_secret_credentials_id_seq OWNED BY public.visitor_secret_credentials.id;


--
-- Name: visitor_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_statuses_id_seq OWNED BY public.visitor_statuses.id;


--
-- Name: visitor_telephone_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_telephone_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_telephone_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_telephone_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_telephone_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_telephone_statuses_id_seq OWNED BY public.visitor_telephone_statuses.id;


--
-- Name: visitor_telephones; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_telephones (
    id bigint NOT NULL,
    number character varying DEFAULT ''::character varying NOT NULL,
    number_digest character varying,
    locked_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    visitor_telephone_status_id bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: visitor_telephones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_telephones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_telephones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_telephones_id_seq OWNED BY public.visitor_telephones.id;


--
-- Name: visitor_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_visibilities (
    id bigint NOT NULL
);


--
-- Name: visitor_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_visibilities_id_seq OWNED BY public.visitor_visibilities.id;


--
-- Name: visitor_withdrawal_flow_events; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_flow_events (
    id bigint NOT NULL,
    visitor_withdrawal_flow_id bigint NOT NULL,
    visitor_id bigint NOT NULL,
    from_status_id bigint,
    to_status_id bigint NOT NULL,
    occurred_at timestamp(6) with time zone NOT NULL,
    token_public_id character varying(64) DEFAULT ''::character varying NOT NULL,
    reason character varying(64) DEFAULT ''::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: visitor_withdrawal_flow_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_flow_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_flow_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_flow_events_id_seq OWNED BY public.visitor_withdrawal_flow_events.id;


--
-- Name: visitor_withdrawal_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: visitor_withdrawal_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_flow_statuses_id_seq OWNED BY public.visitor_withdrawal_flow_statuses.id;


--
-- Name: visitor_withdrawal_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitor_withdrawal_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    visitor_id bigint NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    began_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_visitor_withdrawal_cycles_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: visitor_withdrawal_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitor_withdrawal_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitor_withdrawal_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitor_withdrawal_flows_id_seq OWNED BY public.visitor_withdrawal_flows.id;


--
-- Name: visitors; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.visitors (
    id bigint NOT NULL,
    deactivated_at timestamp(6) with time zone,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    public_id character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 2 NOT NULL,
    visibility_id bigint DEFAULT 1 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    withdrawn_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp without time zone,
    withdrawal_started_at timestamp(6) with time zone,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    terminated_at timestamp(6) with time zone,
    birthdate text,
    CONSTRAINT chk_customers_retention_order CHECK ((discarded_at <= purged_at)),
    CONSTRAINT chk_visitors_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000)))
);


--
-- Name: visitors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE UNLOGGED SEQUENCE public.visitors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitors_id_seq OWNED BY public.visitors.id;


--
-- Name: action_push_native_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_push_native_devices ALTER COLUMN id SET DEFAULT nextval('public.action_push_native_devices_id_seq'::regclass);


--
-- Name: visitor_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_banners ALTER COLUMN id SET DEFAULT nextval('public.visitor_banners_id_seq'::regclass);


--
-- Name: visitor_email_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_email_statuses_id_seq'::regclass);


--
-- Name: visitor_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails ALTER COLUMN id SET DEFAULT nextval('public.visitor_emails_id_seq'::regclass);


--
-- Name: visitor_mfa_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_levels ALTER COLUMN id SET DEFAULT nextval('public.visitor_mfa_levels_id_seq'::regclass);


--
-- Name: visitor_mfa_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_mfa_statuses_id_seq'::regclass);


--
-- Name: visitor_passkey_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkey_statuses_id_seq'::regclass);


--
-- Name: visitor_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys ALTER COLUMN id SET DEFAULT nextval('public.visitor_passkeys_id_seq'::regclass);


--
-- Name: visitor_preference_adult_content_gate_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gate_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_adult_content_gate_options_id_seq'::regclass);


--
-- Name: visitor_preference_adult_content_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_adult_content_gates_id_seq'::regclass);


--
-- Name: visitor_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_currencies_id_seq'::regclass);


--
-- Name: visitor_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_currency_options_id_seq'::regclass);


--
-- Name: visitor_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_date_format_options_id_seq'::regclass);


--
-- Name: visitor_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_date_formats_id_seq'::regclass);


--
-- Name: visitor_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_densities_id_seq'::regclass);


--
-- Name: visitor_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_density_options_id_seq'::regclass);


--
-- Name: visitor_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_language_options_id_seq'::regclass);


--
-- Name: visitor_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_languages_id_seq'::regclass);


--
-- Name: visitor_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_motion_options_id_seq'::regclass);


--
-- Name: visitor_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_motions_id_seq'::regclass);


--
-- Name: visitor_preference_page_size_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_size_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_page_size_options_id_seq'::regclass);


--
-- Name: visitor_preference_page_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_page_sizes_id_seq'::regclass);


--
-- Name: visitor_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_region_options_id_seq'::regclass);


--
-- Name: visitor_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_regions_id_seq'::regclass);


--
-- Name: visitor_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_theme_options_id_seq'::regclass);


--
-- Name: visitor_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_themes_id_seq'::regclass);


--
-- Name: visitor_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_time_format_options_id_seq'::regclass);


--
-- Name: visitor_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_time_formats_id_seq'::regclass);


--
-- Name: visitor_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_timezone_options_id_seq'::regclass);


--
-- Name: visitor_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.visitor_preference_timezones_id_seq'::regclass);


--
-- Name: visitor_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preferences ALTER COLUMN id SET DEFAULT nextval('public.visitor_preferences_id_seq'::regclass);


--
-- Name: visitor_secret_credential_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_kinds ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credential_kinds_id_seq'::regclass);


--
-- Name: visitor_secret_credential_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credential_statuses_id_seq'::regclass);


--
-- Name: visitor_secret_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials ALTER COLUMN id SET DEFAULT nextval('public.visitor_secret_credentials_id_seq'::regclass);


--
-- Name: visitor_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_statuses_id_seq'::regclass);


--
-- Name: visitor_telephone_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephone_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_telephone_statuses_id_seq'::regclass);


--
-- Name: visitor_telephones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones ALTER COLUMN id SET DEFAULT nextval('public.visitor_telephones_id_seq'::regclass);


--
-- Name: visitor_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_visibilities ALTER COLUMN id SET DEFAULT nextval('public.visitor_visibilities_id_seq'::regclass);


--
-- Name: visitor_withdrawal_flow_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_flow_events_id_seq'::regclass);


--
-- Name: visitor_withdrawal_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_flow_statuses_id_seq'::regclass);


--
-- Name: visitor_withdrawal_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows ALTER COLUMN id SET DEFAULT nextval('public.visitor_withdrawal_flows_id_seq'::regclass);


--
-- Name: visitors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors ALTER COLUMN id SET DEFAULT nextval('public.visitors_id_seq'::regclass);


--
-- Name: action_push_native_devices action_push_native_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_push_native_devices
    ADD CONSTRAINT action_push_native_devices_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: visitor_emails chk_visitor_emails_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_emails
    ADD CONSTRAINT chk_visitor_emails_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: visitor_passkeys chk_visitor_passkeys_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_passkeys
    ADD CONSTRAINT chk_visitor_passkeys_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: visitor_telephones chk_visitor_telephones_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitor_telephones
    ADD CONSTRAINT chk_visitor_telephones_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: visitors chk_visitors_mfa_requirement_consistency; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitors
    ADD CONSTRAINT chk_visitors_mfa_requirement_consistency CHECK ((((mfa_level_enabled = false) AND (mfa_level_id = 0)) OR ((mfa_level_enabled = true) AND (mfa_level_id <> 0)))) NOT VALID;


--
-- Name: visitors chk_visitors_terminated_requires_withdrawn; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitors
    ADD CONSTRAINT chk_visitors_terminated_requires_withdrawn CHECK (((terminated_at IS NULL) OR ((withdrawn_at IS NOT NULL) AND (withdrawn_at < 'infinity'::timestamp without time zone)))) NOT VALID;


--
-- Name: visitors chk_visitors_withdrawal_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.visitors
    ADD CONSTRAINT chk_visitors_withdrawal_order CHECK (((withdrawal_started_at IS NULL) OR (withdrawn_at IS NULL) OR (withdrawn_at = 'infinity'::timestamp without time zone) OR (withdrawal_started_at <= withdrawn_at))) NOT VALID;


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: visitor_banners visitor_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_banners
    ADD CONSTRAINT visitor_banners_pkey PRIMARY KEY (id);


--
-- Name: visitor_email_statuses visitor_email_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_email_statuses
    ADD CONSTRAINT visitor_email_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_emails visitor_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT visitor_emails_pkey PRIMARY KEY (id);


--
-- Name: visitor_mfa_levels visitor_mfa_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_levels
    ADD CONSTRAINT visitor_mfa_levels_pkey PRIMARY KEY (id);


--
-- Name: visitor_mfa_statuses visitor_mfa_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_mfa_statuses
    ADD CONSTRAINT visitor_mfa_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_passkey_statuses visitor_passkey_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkey_statuses
    ADD CONSTRAINT visitor_passkey_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_passkeys visitor_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT visitor_passkeys_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_adult_content_gate_options visitor_preference_adult_content_gate_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gate_options
    ADD CONSTRAINT visitor_preference_adult_content_gate_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_adult_content_gates visitor_preference_adult_content_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates
    ADD CONSTRAINT visitor_preference_adult_content_gates_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_currencies visitor_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies
    ADD CONSTRAINT visitor_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_currency_options visitor_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currency_options
    ADD CONSTRAINT visitor_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_date_format_options visitor_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_format_options
    ADD CONSTRAINT visitor_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_date_formats visitor_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats
    ADD CONSTRAINT visitor_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_densities visitor_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities
    ADD CONSTRAINT visitor_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_density_options visitor_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_density_options
    ADD CONSTRAINT visitor_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_language_options visitor_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_language_options
    ADD CONSTRAINT visitor_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_languages visitor_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages
    ADD CONSTRAINT visitor_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_motion_options visitor_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motion_options
    ADD CONSTRAINT visitor_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_motions visitor_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions
    ADD CONSTRAINT visitor_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_page_size_options visitor_preference_page_size_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_size_options
    ADD CONSTRAINT visitor_preference_page_size_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_page_sizes visitor_preference_page_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes
    ADD CONSTRAINT visitor_preference_page_sizes_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_region_options visitor_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_region_options
    ADD CONSTRAINT visitor_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_regions visitor_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions
    ADD CONSTRAINT visitor_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_theme_options visitor_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_theme_options
    ADD CONSTRAINT visitor_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_themes visitor_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes
    ADD CONSTRAINT visitor_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_time_format_options visitor_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_format_options
    ADD CONSTRAINT visitor_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_time_formats visitor_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats
    ADD CONSTRAINT visitor_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_timezone_options visitor_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezone_options
    ADD CONSTRAINT visitor_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: visitor_preference_timezones visitor_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones
    ADD CONSTRAINT visitor_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: visitor_preferences visitor_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preferences
    ADD CONSTRAINT visitor_preferences_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credential_kinds visitor_secret_credential_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_kinds
    ADD CONSTRAINT visitor_secret_credential_kinds_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credential_statuses visitor_secret_credential_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credential_statuses
    ADD CONSTRAINT visitor_secret_credential_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_secret_credentials visitor_secret_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT visitor_secret_credentials_pkey PRIMARY KEY (id);


--
-- Name: visitor_statuses visitor_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_statuses
    ADD CONSTRAINT visitor_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_telephone_statuses visitor_telephone_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephone_statuses
    ADD CONSTRAINT visitor_telephone_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_telephones visitor_telephones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT visitor_telephones_pkey PRIMARY KEY (id);


--
-- Name: visitor_visibilities visitor_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_visibilities
    ADD CONSTRAINT visitor_visibilities_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_flow_events visitor_withdrawal_flow_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT visitor_withdrawal_flow_events_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_flow_statuses visitor_withdrawal_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_statuses
    ADD CONSTRAINT visitor_withdrawal_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: visitor_withdrawal_flows visitor_withdrawal_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT visitor_withdrawal_flows_pkey PRIMARY KEY (id);


--
-- Name: visitors visitors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT visitors_pkey PRIMARY KEY (id);


--
-- Name: idx_on_visitor_secret_credential_kind_id_80c2fa07fe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_secret_credential_kind_id_80c2fa07fe ON public.visitor_secret_credentials USING btree (visitor_secret_credential_kind_id);


--
-- Name: idx_on_visitor_secret_credential_status_id_a8132e5a1a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_secret_credential_status_id_a8132e5a1a ON public.visitor_secret_credentials USING btree (visitor_secret_credential_status_id);


--
-- Name: idx_on_visitor_withdrawal_flow_id_dada4f9f5b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_visitor_withdrawal_flow_id_dada4f9f5b ON public.visitor_withdrawal_flow_events USING btree (visitor_withdrawal_flow_id);


--
-- Name: index_action_push_native_devices_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_action_push_native_devices_on_owner ON public.action_push_native_devices USING btree (owner_type, owner_id);


--
-- Name: index_visitor_banners_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_banners_on_visitor_id ON public.visitor_banners USING btree (visitor_id);


--
-- Name: index_visitor_emails_on_active_address_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_emails_on_active_address_digest ON public.visitor_emails USING btree (address_digest) WHERE ((address_digest IS NOT NULL) AND (visitor_email_status_id <> 4));


--
-- Name: index_visitor_emails_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_discarded_at ON public.visitor_emails USING btree (discarded_at);


--
-- Name: index_visitor_emails_on_otp_last_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_otp_last_sent_at ON public.visitor_emails USING btree (otp_last_sent_at);


--
-- Name: index_visitor_emails_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_emails_on_public_id ON public.visitor_emails USING btree (public_id);


--
-- Name: index_visitor_emails_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_purged_at ON public.visitor_emails USING btree (purged_at);


--
-- Name: index_visitor_emails_on_visitor_email_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_visitor_email_status_id ON public.visitor_emails USING btree (visitor_email_status_id);


--
-- Name: index_visitor_emails_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_emails_on_visitor_id ON public.visitor_emails USING btree (visitor_id);


--
-- Name: index_visitor_passkeys_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_discarded_at ON public.visitor_passkeys USING btree (discarded_at);


--
-- Name: index_visitor_passkeys_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkeys_on_public_id ON public.visitor_passkeys USING btree (public_id);


--
-- Name: index_visitor_passkeys_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_purged_at ON public.visitor_passkeys USING btree (purged_at);


--
-- Name: index_visitor_passkeys_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_status_id ON public.visitor_passkeys USING btree (status_id);


--
-- Name: index_visitor_passkeys_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_passkeys_on_visitor_id ON public.visitor_passkeys USING btree (visitor_id);


--
-- Name: index_visitor_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_passkeys_on_webauthn_id ON public.visitor_passkeys USING btree (webauthn_id);


--
-- Name: index_visitor_preference_adult_content_gates_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_adult_content_gates_on_option_id ON public.visitor_preference_adult_content_gates USING btree (option_id);


--
-- Name: index_visitor_preference_adult_content_gates_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_adult_content_gates_on_preference_id ON public.visitor_preference_adult_content_gates USING btree (preference_id);


--
-- Name: index_visitor_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_currencies_on_option_id ON public.visitor_preference_currencies USING btree (option_id);


--
-- Name: index_visitor_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_currencies_on_preference_id ON public.visitor_preference_currencies USING btree (preference_id);


--
-- Name: index_visitor_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_date_formats_on_option_id ON public.visitor_preference_date_formats USING btree (option_id);


--
-- Name: index_visitor_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_date_formats_on_preference_id ON public.visitor_preference_date_formats USING btree (preference_id);


--
-- Name: index_visitor_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_densities_on_option_id ON public.visitor_preference_densities USING btree (option_id);


--
-- Name: index_visitor_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_densities_on_preference_id ON public.visitor_preference_densities USING btree (preference_id);


--
-- Name: index_visitor_preference_language_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_language_options_on_id ON public.visitor_preference_language_options USING btree (id);


--
-- Name: index_visitor_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_languages_on_option_id ON public.visitor_preference_languages USING btree (option_id);


--
-- Name: index_visitor_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_languages_on_preference_id ON public.visitor_preference_languages USING btree (preference_id);


--
-- Name: index_visitor_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_motions_on_option_id ON public.visitor_preference_motions USING btree (option_id);


--
-- Name: index_visitor_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_motions_on_preference_id ON public.visitor_preference_motions USING btree (preference_id);


--
-- Name: index_visitor_preference_page_sizes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_page_sizes_on_option_id ON public.visitor_preference_page_sizes USING btree (option_id);


--
-- Name: index_visitor_preference_page_sizes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_page_sizes_on_preference_id ON public.visitor_preference_page_sizes USING btree (preference_id);


--
-- Name: index_visitor_preference_region_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_region_options_on_id ON public.visitor_preference_region_options USING btree (id);


--
-- Name: index_visitor_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_regions_on_option_id ON public.visitor_preference_regions USING btree (option_id);


--
-- Name: index_visitor_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_regions_on_preference_id ON public.visitor_preference_regions USING btree (preference_id);


--
-- Name: index_visitor_preference_theme_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_theme_options_on_id ON public.visitor_preference_theme_options USING btree (id);


--
-- Name: index_visitor_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_themes_on_option_id ON public.visitor_preference_themes USING btree (option_id);


--
-- Name: index_visitor_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_themes_on_preference_id ON public.visitor_preference_themes USING btree (preference_id);


--
-- Name: index_visitor_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_time_formats_on_option_id ON public.visitor_preference_time_formats USING btree (option_id);


--
-- Name: index_visitor_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_time_formats_on_preference_id ON public.visitor_preference_time_formats USING btree (preference_id);


--
-- Name: index_visitor_preference_timezone_options_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_timezone_options_on_id ON public.visitor_preference_timezone_options USING btree (id);


--
-- Name: index_visitor_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_preference_timezones_on_option_id ON public.visitor_preference_timezones USING btree (option_id);


--
-- Name: index_visitor_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preference_timezones_on_preference_id ON public.visitor_preference_timezones USING btree (preference_id);


--
-- Name: index_visitor_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preferences_on_public_id ON public.visitor_preferences USING btree (public_id);


--
-- Name: index_visitor_preferences_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_preferences_on_visitor_id ON public.visitor_preferences USING btree (visitor_id);


--
-- Name: index_visitor_secret_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_secret_credentials_on_public_id ON public.visitor_secret_credentials USING btree (public_id);


--
-- Name: index_visitor_secret_credentials_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_secret_credentials_on_visitor_id ON public.visitor_secret_credentials USING btree (visitor_id);


--
-- Name: index_visitor_telephones_on_active_number_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_telephones_on_active_number_digest ON public.visitor_telephones USING btree (number_digest) WHERE ((number_digest IS NOT NULL) AND (visitor_telephone_status_id <> 4));


--
-- Name: index_visitor_telephones_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_discarded_at ON public.visitor_telephones USING btree (discarded_at);


--
-- Name: index_visitor_telephones_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_telephones_on_public_id ON public.visitor_telephones USING btree (public_id);


--
-- Name: index_visitor_telephones_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_purged_at ON public.visitor_telephones USING btree (purged_at);


--
-- Name: index_visitor_telephones_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_visitor_id ON public.visitor_telephones USING btree (visitor_id);


--
-- Name: index_visitor_telephones_on_visitor_telephone_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_telephones_on_visitor_telephone_status_id ON public.visitor_telephones USING btree (visitor_telephone_status_id);


--
-- Name: index_visitor_withdrawal_flow_events_on_from_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_from_status_id ON public.visitor_withdrawal_flow_events USING btree (from_status_id);


--
-- Name: index_visitor_withdrawal_flow_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_occurred_at ON public.visitor_withdrawal_flow_events USING btree (occurred_at);


--
-- Name: index_visitor_withdrawal_flow_events_on_to_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_to_status_id ON public.visitor_withdrawal_flow_events USING btree (to_status_id);


--
-- Name: index_visitor_withdrawal_flow_events_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flow_events_on_visitor_id ON public.visitor_withdrawal_flow_events USING btree (visitor_id);


--
-- Name: index_visitor_withdrawal_flows_on_began_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_began_at ON public.visitor_withdrawal_flows USING btree (began_at);


--
-- Name: index_visitor_withdrawal_flows_on_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_completed_at ON public.visitor_withdrawal_flows USING btree (completed_at);


--
-- Name: index_visitor_withdrawal_flows_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_discarded_at ON public.visitor_withdrawal_flows USING btree (discarded_at);


--
-- Name: index_visitor_withdrawal_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitor_withdrawal_flows_on_public_id ON public.visitor_withdrawal_flows USING btree (public_id);


--
-- Name: index_visitor_withdrawal_flows_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_purged_at ON public.visitor_withdrawal_flows USING btree (purged_at);


--
-- Name: index_visitor_withdrawal_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_status_id ON public.visitor_withdrawal_flows USING btree (status_id);


--
-- Name: index_visitor_withdrawal_flows_on_visitor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitor_withdrawal_flows_on_visitor_id ON public.visitor_withdrawal_flows USING btree (visitor_id);


--
-- Name: index_visitors_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_deactivated_at ON public.visitors USING btree (deactivated_at) WHERE (deactivated_at IS NOT NULL);


--
-- Name: index_visitors_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_discarded_at ON public.visitors USING btree (discarded_at);


--
-- Name: index_visitors_on_mfa_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_mfa_level_id ON public.visitors USING btree (mfa_level_id);


--
-- Name: index_visitors_on_mfa_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_mfa_status_id ON public.visitors USING btree (mfa_status_id);


--
-- Name: index_visitors_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visitors_on_public_id ON public.visitors USING btree (public_id);


--
-- Name: index_visitors_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_purged_at ON public.visitors USING btree (purged_at);


--
-- Name: index_visitors_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_status_id ON public.visitors USING btree (status_id);


--
-- Name: index_visitors_on_terminated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_terminated_at ON public.visitors USING btree (terminated_at) WHERE (terminated_at IS NOT NULL);


--
-- Name: index_visitors_on_visibility_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_visibility_id ON public.visitors USING btree (visibility_id);


--
-- Name: index_visitors_on_withdrawal_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_withdrawal_started_at ON public.visitors USING btree (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL);


--
-- Name: index_visitors_on_withdrawn_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_visitors_on_withdrawn_at ON public.visitors USING btree (withdrawn_at) WHERE (withdrawn_at IS NOT NULL);


--
-- Name: visitor_preference_page_sizes fk_rails_014019b4c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes
    ADD CONSTRAINT fk_rails_014019b4c4 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_page_sizes fk_rails_06044e10ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_page_sizes
    ADD CONSTRAINT fk_rails_06044e10ed FOREIGN KEY (option_id) REFERENCES public.visitor_preference_page_size_options(id);


--
-- Name: visitor_emails fk_rails_07ea0750f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT fk_rails_07ea0750f3 FOREIGN KEY (visitor_email_status_id) REFERENCES public.visitor_email_statuses(id);


--
-- Name: visitors fk_rails_15c7fee824; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_15c7fee824 FOREIGN KEY (mfa_level_id) REFERENCES public.visitor_mfa_levels(id);


--
-- Name: visitor_preference_languages fk_rails_1bfc60dac9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages
    ADD CONSTRAINT fk_rails_1bfc60dac9 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_language_options(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_24dd59e35d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_24dd59e35d FOREIGN KEY (from_status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) NOT VALID;


--
-- Name: visitor_telephones fk_rails_2de4d12c9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT fk_rails_2de4d12c9f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_secret_credentials fk_rails_2ee7e81748; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_2ee7e81748 FOREIGN KEY (visitor_secret_credential_status_id) REFERENCES public.visitor_secret_credential_statuses(id);


--
-- Name: visitor_banners fk_rails_329012d103; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_banners
    ADD CONSTRAINT fk_rails_329012d103 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id) NOT VALID;


--
-- Name: visitor_preference_adult_content_gates fk_rails_33ff94718e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_33ff94718e FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_densities fk_rails_3804faa7b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities
    ADD CONSTRAINT fk_rails_3804faa7b8 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_densities fk_rails_3ae8df8c50; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_densities
    ADD CONSTRAINT fk_rails_3ae8df8c50 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_density_options(id);


--
-- Name: visitor_passkeys fk_rails_3ced60caec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT fk_rails_3ced60caec FOREIGN KEY (status_id) REFERENCES public.visitor_passkey_statuses(id);


--
-- Name: visitor_withdrawal_flows fk_rails_3e7b55d34f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT fk_rails_3e7b55d34f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id) NOT VALID;


--
-- Name: visitor_preference_time_formats fk_rails_3ec34cc9a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats
    ADD CONSTRAINT fk_rails_3ec34cc9a9 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_time_format_options(id);


--
-- Name: visitor_secret_credentials fk_rails_41951b924f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_41951b924f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_date_formats fk_rails_4433ba0e7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats
    ADD CONSTRAINT fk_rails_4433ba0e7f FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_55a6a6bfd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_55a6a6bfd5 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id) NOT VALID;


--
-- Name: visitor_preference_themes fk_rails_55a774df73; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes
    ADD CONSTRAINT fk_rails_55a774df73 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_606617dd12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_606617dd12 FOREIGN KEY (visitor_withdrawal_flow_id) REFERENCES public.visitor_withdrawal_flows(id) NOT VALID;


--
-- Name: visitor_preference_motions fk_rails_654c495cfe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions
    ADD CONSTRAINT fk_rails_654c495cfe FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_regions fk_rails_6caa4ea665; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions
    ADD CONSTRAINT fk_rails_6caa4ea665 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitors fk_rails_6e2a03b63d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_6e2a03b63d FOREIGN KEY (mfa_status_id) REFERENCES public.visitor_mfa_statuses(id);


--
-- Name: visitor_preference_regions fk_rails_77bf53dc27; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_regions
    ADD CONSTRAINT fk_rails_77bf53dc27 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_region_options(id);


--
-- Name: visitor_withdrawal_flows fk_rails_8021cd7888; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flows
    ADD CONSTRAINT fk_rails_8021cd7888 FOREIGN KEY (status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) NOT VALID;


--
-- Name: visitor_preference_languages fk_rails_8bf3bcafe7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_languages
    ADD CONSTRAINT fk_rails_8bf3bcafe7 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_emails fk_rails_9525e3bd11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_emails
    ADD CONSTRAINT fk_rails_9525e3bd11 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_timezones fk_rails_9581543eba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones
    ADD CONSTRAINT fk_rails_9581543eba FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_currencies fk_rails_9aa83176b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies
    ADD CONSTRAINT fk_rails_9aa83176b2 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_currency_options(id);


--
-- Name: visitor_preference_adult_content_gates fk_rails_a04d2550c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_a04d2550c9 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_adult_content_gate_options(id);


--
-- Name: visitor_preference_currencies fk_rails_b17c0b68b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_currencies
    ADD CONSTRAINT fk_rails_b17c0b68b8 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitors fk_rails_b66f17957a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_b66f17957a FOREIGN KEY (status_id) REFERENCES public.visitor_statuses(id);


--
-- Name: visitor_withdrawal_flow_events fk_rails_bb8f094ca9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_bb8f094ca9 FOREIGN KEY (to_status_id) REFERENCES public.visitor_withdrawal_flow_statuses(id) NOT VALID;


--
-- Name: visitor_telephones fk_rails_c534739d95; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_telephones
    ADD CONSTRAINT fk_rails_c534739d95 FOREIGN KEY (visitor_telephone_status_id) REFERENCES public.visitor_telephone_statuses(id);


--
-- Name: visitor_preferences fk_rails_c56f0041b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preferences
    ADD CONSTRAINT fk_rails_c56f0041b9 FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_passkeys fk_rails_cb59e99a6f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_passkeys
    ADD CONSTRAINT fk_rails_cb59e99a6f FOREIGN KEY (visitor_id) REFERENCES public.visitors(id);


--
-- Name: visitor_preference_motions fk_rails_d111a7bfa7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_motions
    ADD CONSTRAINT fk_rails_d111a7bfa7 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_motion_options(id);


--
-- Name: visitor_preference_time_formats fk_rails_d178d34815; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_time_formats
    ADD CONSTRAINT fk_rails_d178d34815 FOREIGN KEY (preference_id) REFERENCES public.visitor_preferences(id);


--
-- Name: visitor_preference_date_formats fk_rails_d2280f99f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_date_formats
    ADD CONSTRAINT fk_rails_d2280f99f6 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_date_format_options(id);


--
-- Name: visitors fk_rails_d25b75677b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitors
    ADD CONSTRAINT fk_rails_d25b75677b FOREIGN KEY (visibility_id) REFERENCES public.visitor_visibilities(id);


--
-- Name: visitor_secret_credentials fk_rails_e1dad63cb9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_secret_credentials
    ADD CONSTRAINT fk_rails_e1dad63cb9 FOREIGN KEY (visitor_secret_credential_kind_id) REFERENCES public.visitor_secret_credential_kinds(id);


--
-- Name: visitor_preference_timezones fk_rails_e71018d351; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_timezones
    ADD CONSTRAINT fk_rails_e71018d351 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_timezone_options(id);


--
-- Name: visitor_preference_themes fk_rails_eb8a488b93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitor_preference_themes
    ADD CONSTRAINT fk_rails_eb8a488b93 FOREIGN KEY (option_id) REFERENCES public.visitor_preference_theme_options(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260530032500'),
('20260530032400'),
('20260530032200'),
('20260530032100'),
('20260530031000'),
('20260528162002'),
('20260526090000'),
('20260525131000'),
('20260525120000'),
('20260519173000'),
('20260519094001'),
('20260518181000'),
('20260518180000'),
('20260518170600'),
('20260518170500'),
('20260518170001'),
('20260518170000'),
('20260518163000'),
('20260518121001'),
('20260518121000'),
('20260518120000'),
('20260514143000'),
('20260514140000'),
('20260513161000'),
('20260513130000'),
('20260513121500'),
('20260512111000'),
('20260508151000'),
('20260508150000'),
('20260508140999'),
('20260508140932'),
('20260508135008'),
('20260508135006'),
('20260506194400'),
('20260329120000'),
('20260329084527'),
('20260329021000'),
('20260329020000'),
('20260329010000'),
('20260325143000'),
('20260309000001'),
('20260202220000'),
('20251230080061'),
('20251230060001'),
('20251228000007'),
('20251228000001'),
('20251226012721'),
('20251224171000'),
('20240627130203');

