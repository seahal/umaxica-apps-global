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
-- Name: check_user_identity_emails_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_emails_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE emails_count integer; BEGIN IF NEW.user_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO emails_count FROM user_identity_emails WHERE user_id = NEW.user_id; IF emails_count >= 4 THEN RAISE EXCEPTION 'user_identity_emails limit (4) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_passkeys_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_passkeys_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE passkeys_count integer; BEGIN SELECT COUNT(*) INTO passkeys_count FROM user_identity_passkeys WHERE user_id = NEW.user_id; IF passkeys_count >= 4 THEN RAISE EXCEPTION 'user_identity_passkeys limit (4) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_secrets_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_secrets_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE secrets_count integer; BEGIN SELECT COUNT(*) INTO secrets_count FROM user_identity_secrets WHERE user_id = NEW.user_id; IF secrets_count >= 10 THEN RAISE EXCEPTION 'user_identity_secrets limit (10) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_telephones_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_telephones_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE telephones_count integer; BEGIN IF NEW.user_id IS NULL THEN RETURN NEW; END IF; SELECT COUNT(*) INTO telephones_count FROM user_identity_telephones WHERE user_id = NEW.user_id; IF telephones_count >= 4 THEN RAISE EXCEPTION 'user_identity_telephones limit (4) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


--
-- Name: check_user_identity_totp_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_identity_totp_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE totp_count integer; BEGIN SELECT COUNT(*) INTO totp_count FROM user_identity_one_time_passwords WHERE user_id = NEW.user_id; IF totp_count >= 2 THEN RAISE EXCEPTION 'user_identity_one_time_passwords limit (2) exceeded for user %', NEW.user_id USING ERRCODE = '23514'; END IF; RETURN NEW; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    accountable_id bigint NOT NULL,
    accountable_type character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: apple_auths; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apple_auths (
    id bigint NOT NULL,
    access_token text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    provider character varying DEFAULT ''::character varying NOT NULL,
    refresh_token text NOT NULL,
    uid character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: apple_auths_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.apple_auths_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: apple_auths_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.apple_auths_id_seq OWNED BY public.apple_auths.id;


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
-- Name: client_apple_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_apple_identities (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    token_expires_at integer NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    provider character varying DEFAULT 'apple'::character varying NOT NULL,
    refresh_token character varying DEFAULT ''::character varying NOT NULL,
    token character varying DEFAULT ''::character varying NOT NULL,
    uid character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: client_apple_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_apple_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_apple_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_apple_identities_id_seq OWNED BY public.client_apple_identities.id;


--
-- Name: client_apple_identity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_apple_identity_statuses (
    id bigint NOT NULL
);


--
-- Name: client_apple_identity_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_apple_identity_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_apple_identity_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_apple_identity_statuses_id_seq OWNED BY public.client_apple_identity_statuses.id;


--
-- Name: client_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_banners (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    published boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT user_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: client_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_banners_id_seq OWNED BY public.client_banners.id;


--
-- Name: client_bulletins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_bulletins (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    title character varying NOT NULL,
    body text,
    read_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_bulletins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_bulletins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_bulletins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_bulletins_id_seq OWNED BY public.client_bulletins.id;


--
-- Name: client_email_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_email_statuses (
    id bigint NOT NULL
);


--
-- Name: client_email_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_email_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_email_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_email_statuses_id_seq OWNED BY public.client_email_statuses.id;


--
-- Name: client_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_emails (
    id bigint NOT NULL,
    address character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    locked_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_last_sent_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    verification_token_digest bytea,
    user_email_status_id bigint DEFAULT 0 NOT NULL,
    address_digest character varying,
    undeletable boolean DEFAULT false NOT NULL,
    promotional boolean DEFAULT true NOT NULL,
    notifiable boolean DEFAULT true NOT NULL,
    subscribable boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: client_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_emails_id_seq OWNED BY public.client_emails.id;


--
-- Name: client_google_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_google_identities (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    token_expires_at integer NOT NULL,
    last_authenticated_at timestamp(6) with time zone,
    provider character varying DEFAULT 'google'::character varying NOT NULL,
    refresh_token character varying DEFAULT ''::character varying NOT NULL,
    token character varying DEFAULT ''::character varying NOT NULL,
    uid character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: client_google_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_google_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_google_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_google_identities_id_seq OWNED BY public.client_google_identities.id;


--
-- Name: client_google_identity_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_google_identity_statuses (
    id bigint NOT NULL
);


--
-- Name: client_google_identity_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_google_identity_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_google_identity_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_google_identity_statuses_id_seq OWNED BY public.client_google_identity_statuses.id;


--
-- Name: client_member_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_deletions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_member_deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_deletions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_deletions_id_seq OWNED BY public.client_member_deletions.id;


--
-- Name: client_member_discoveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_discoveries (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_member_discoveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_discoveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_discoveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_discoveries_id_seq OWNED BY public.client_member_discoveries.id;


--
-- Name: client_member_impersonations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_impersonations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_member_impersonations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_impersonations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_impersonations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_impersonations_id_seq OWNED BY public.client_member_impersonations.id;


--
-- Name: client_member_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_observations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_member_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_observations_id_seq OWNED BY public.client_member_observations.id;


--
-- Name: client_member_revocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_revocations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_member_revocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_revocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_revocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_revocations_id_seq OWNED BY public.client_member_revocations.id;


--
-- Name: client_member_suspensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_member_suspensions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_member_suspensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_member_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_member_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_member_suspensions_id_seq OWNED BY public.client_member_suspensions.id;


--
-- Name: client_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_members (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    member_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_members_id_seq OWNED BY public.client_members.id;


--
-- Name: client_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_memberships (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    joined_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    left_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL
);


--
-- Name: client_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_memberships_id_seq OWNED BY public.client_memberships.id;


--
-- Name: client_mfa_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_mfa_levels (
    id bigint NOT NULL
);


--
-- Name: client_mfa_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_mfa_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_mfa_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_mfa_levels_id_seq OWNED BY public.client_mfa_levels.id;


--
-- Name: client_mfa_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_mfa_statuses (
    id bigint NOT NULL
);


--
-- Name: client_mfa_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_mfa_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_mfa_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_mfa_statuses_id_seq OWNED BY public.client_mfa_statuses.id;


--
-- Name: client_passkey_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkey_statuses (
    id bigint NOT NULL
);


--
-- Name: client_passkey_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkey_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkey_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkey_statuses_id_seq OWNED BY public.client_passkey_statuses.id;


--
-- Name: client_passkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkeys (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    external_id uuid NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    webauthn_id character varying DEFAULT ''::character varying NOT NULL,
    status_id bigint DEFAULT 1 NOT NULL,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: client_passkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkeys_id_seq OWNED BY public.client_passkeys.id;


--
-- Name: client_preference_adult_content_gate_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_adult_content_gate_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_adult_content_gate_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_adult_content_gate_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_adult_content_gate_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_adult_content_gate_options_id_seq OWNED BY public.client_preference_adult_content_gate_options.id;


--
-- Name: client_preference_adult_content_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_adult_content_gates (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_adult_content_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_adult_content_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_adult_content_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_adult_content_gates_id_seq OWNED BY public.client_preference_adult_content_gates.id;


--
-- Name: client_preference_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_currencies (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_currencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_currencies_id_seq OWNED BY public.client_preference_currencies.id;


--
-- Name: client_preference_currency_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_currency_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_currency_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_currency_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_currency_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_currency_options_id_seq OWNED BY public.client_preference_currency_options.id;


--
-- Name: client_preference_date_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_date_format_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_date_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_date_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_date_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_date_format_options_id_seq OWNED BY public.client_preference_date_format_options.id;


--
-- Name: client_preference_date_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_date_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_date_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_date_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_date_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_date_formats_id_seq OWNED BY public.client_preference_date_formats.id;


--
-- Name: client_preference_densities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_densities (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_densities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_densities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_densities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_densities_id_seq OWNED BY public.client_preference_densities.id;


--
-- Name: client_preference_density_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_density_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_density_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_density_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_density_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_density_options_id_seq OWNED BY public.client_preference_density_options.id;


--
-- Name: client_preference_language_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_language_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_language_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_language_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_language_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_language_options_id_seq OWNED BY public.client_preference_language_options.id;


--
-- Name: client_preference_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_languages (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_languages_id_seq OWNED BY public.client_preference_languages.id;


--
-- Name: client_preference_motion_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_motion_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_motion_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_motion_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_motion_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_motion_options_id_seq OWNED BY public.client_preference_motion_options.id;


--
-- Name: client_preference_motions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_motions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_motions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_motions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_motions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_motions_id_seq OWNED BY public.client_preference_motions.id;


--
-- Name: client_preference_page_size_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_page_size_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_page_size_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_page_size_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_page_size_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_page_size_options_id_seq OWNED BY public.client_preference_page_size_options.id;


--
-- Name: client_preference_page_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_page_sizes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_page_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_page_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_page_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_page_sizes_id_seq OWNED BY public.client_preference_page_sizes.id;


--
-- Name: client_preference_region_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_region_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_region_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_region_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_region_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_region_options_id_seq OWNED BY public.client_preference_region_options.id;


--
-- Name: client_preference_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_regions (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_regions_id_seq OWNED BY public.client_preference_regions.id;


--
-- Name: client_preference_theme_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_theme_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_theme_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_theme_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_theme_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_theme_options_id_seq OWNED BY public.client_preference_theme_options.id;


--
-- Name: client_preference_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_themes (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_themes_id_seq OWNED BY public.client_preference_themes.id;


--
-- Name: client_preference_time_format_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_time_format_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_time_format_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_time_format_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_time_format_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_time_format_options_id_seq OWNED BY public.client_preference_time_format_options.id;


--
-- Name: client_preference_time_formats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_time_formats (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_time_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_time_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_time_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_time_formats_id_seq OWNED BY public.client_preference_time_formats.id;


--
-- Name: client_preference_timezone_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_timezone_options (
    id bigint NOT NULL
);


--
-- Name: client_preference_timezone_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_timezone_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_timezone_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_timezone_options_id_seq OWNED BY public.client_preference_timezone_options.id;


--
-- Name: client_preference_timezones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preference_timezones (
    id bigint NOT NULL,
    preference_id bigint NOT NULL,
    option_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_preference_timezones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preference_timezones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preference_timezones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preference_timezones_id_seq OWNED BY public.client_preference_timezones.id;


--
-- Name: client_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    consented boolean DEFAULT false NOT NULL,
    functional boolean DEFAULT false NOT NULL,
    performant boolean DEFAULT false NOT NULL,
    targetable boolean DEFAULT false NOT NULL,
    consented_at timestamp(6) with time zone,
    consent_version uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    language character varying DEFAULT 'ja'::character varying NOT NULL,
    region character varying DEFAULT 'jp'::character varying NOT NULL,
    timezone character varying DEFAULT 'Asia/Tokyo'::character varying NOT NULL,
    theme character varying DEFAULT 'sy'::character varying NOT NULL,
    public_id character varying(21),
    currency character varying DEFAULT 'jpy'::character varying NOT NULL,
    date_format character varying DEFAULT 'iso'::character varying NOT NULL,
    time_format character varying DEFAULT '24'::character varying NOT NULL,
    motion character varying DEFAULT 'standard'::character varying NOT NULL,
    density character varying DEFAULT 'standard'::character varying NOT NULL,
    page_size character varying DEFAULT 'infinity'::character varying NOT NULL
);


--
-- Name: client_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_preferences_id_seq OWNED BY public.client_preferences.id;


--
-- Name: client_secret_credential_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_credential_kinds (
    id bigint NOT NULL
);


--
-- Name: client_secret_credential_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_credential_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_credential_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_credential_kinds_id_seq OWNED BY public.client_secret_credential_kinds.id;


--
-- Name: client_secret_credential_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_credential_statuses (
    id bigint NOT NULL
);


--
-- Name: client_secret_credential_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_credential_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_credential_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_credential_statuses_id_seq OWNED BY public.client_secret_credential_statuses.id;


--
-- Name: client_secret_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_credentials (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_used_at timestamp(6) with time zone,
    name character varying DEFAULT ''::character varying NOT NULL,
    password_digest character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    uses_remaining integer DEFAULT 1 NOT NULL,
    user_identity_secret_status_id bigint DEFAULT 0 NOT NULL,
    user_secret_kind_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    secret_kind character varying,
    usage_policy character varying,
    lookup_digest character varying,
    safe_prefix character varying,
    issued_at timestamp(6) with time zone,
    issued_by_type character varying,
    issued_by_id bigint,
    issued_by_ref character varying,
    delivery_method character varying,
    scope character varying,
    use_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    max_uses integer,
    max_failures integer,
    not_before_at timestamp(6) with time zone,
    consumed_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    locked_at timestamp(6) with time zone,
    last_failed_at timestamp(6) with time zone,
    CONSTRAINT chk_user_secrets_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: client_secret_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_credentials_id_seq OWNED BY public.client_secret_credentials.id;


--
-- Name: client_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_statuses (
    id bigint NOT NULL
);


--
-- Name: client_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_statuses_id_seq OWNED BY public.client_statuses.id;


--
-- Name: client_telephone_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephone_statuses (
    id bigint NOT NULL
);


--
-- Name: client_telephone_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephone_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephone_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephone_statuses_id_seq OWNED BY public.client_telephone_statuses.id;


--
-- Name: client_telephones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephones (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    locked_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    number character varying DEFAULT ''::character varying NOT NULL,
    otp_attempts_count integer DEFAULT 0 NOT NULL,
    otp_counter text DEFAULT ''::text NOT NULL,
    otp_expires_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    otp_private_key character varying DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    user_identity_telephone_status_id bigint DEFAULT 0 NOT NULL,
    public_id character varying(21) NOT NULL,
    number_digest character varying,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: client_telephones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephones_id_seq OWNED BY public.client_telephones.id;


--
-- Name: client_totp_credential_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_totp_credential_statuses (
    id bigint NOT NULL
);


--
-- Name: client_totp_credential_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_totp_credential_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_totp_credential_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_totp_credential_statuses_id_seq OWNED BY public.client_totp_credential_statuses.id;


--
-- Name: client_totp_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_totp_credentials (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_otp_at timestamp(6) with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    private_key character varying(1024) DEFAULT ''::character varying NOT NULL,
    public_id character varying(21) NOT NULL,
    title character varying(32),
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    user_identity_totp_credential_status_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: client_totp_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_totp_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_totp_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_totp_credentials_id_seq OWNED BY public.client_totp_credentials.id;


--
-- Name: client_visibilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_visibilities (
    id bigint NOT NULL
);


--
-- Name: client_visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_visibilities_id_seq OWNED BY public.client_visibilities.id;


--
-- Name: client_withdrawal_flow_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_flow_events (
    id bigint NOT NULL,
    client_withdrawal_flow_id bigint NOT NULL,
    client_id bigint NOT NULL,
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
-- Name: client_withdrawal_flow_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_flow_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_flow_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_flow_events_id_seq OWNED BY public.client_withdrawal_flow_events.id;


--
-- Name: client_withdrawal_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: client_withdrawal_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_flow_statuses_id_seq OWNED BY public.client_withdrawal_flow_statuses.id;


--
-- Name: client_withdrawal_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_withdrawal_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    client_id bigint NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    began_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_withdrawal_cycles_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: client_withdrawal_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_withdrawal_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_withdrawal_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_withdrawal_flows_id_seq OWNED BY public.client_withdrawal_flows.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    public_id character varying(255) DEFAULT ''::character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    withdrawn_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone,
    status_id bigint DEFAULT 11 NOT NULL,
    mfa_level_enabled boolean DEFAULT false NOT NULL,
    withdrawal_started_at timestamp(6) with time zone,
    deactivated_at timestamp(6) with time zone,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    visibility_id bigint DEFAULT 2 NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    mfa_level_id bigint DEFAULT 0 NOT NULL,
    mfa_status_id bigint DEFAULT 5 NOT NULL,
    terminated_at timestamp(6) with time zone,
    birthdate text,
    access_state character varying DEFAULT 'enabled'::character varying NOT NULL,
    admin_locked_at timestamp(6) with time zone,
    admin_locked_by_operator_id bigint,
    admin_locked_reason_code character varying,
    admin_locked_reason_note text,
    token_valid_after_at timestamp(6) with time zone,
    reactivated_at timestamp(6) with time zone,
    CONSTRAINT chk_clients_access_state CHECK (((access_state)::text = ANY ((ARRAY['enabled'::character varying, 'admin_locked'::character varying])::text[]))),
    CONSTRAINT chk_clients_admin_locked_reason_code CHECK (((admin_locked_reason_code IS NULL) OR ((admin_locked_reason_code)::text = ANY ((ARRAY['abuse'::character varying, 'security_incident'::character varying, 'chargeback'::character varying, 'terms_violation'::character varying, 'support_request'::character varying, 'legal_hold'::character varying, 'operator_error_recovery'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT chk_clients_birthdate_length CHECK (((birthdate IS NULL) OR (char_length(birthdate) <= 1000))),
    CONSTRAINT chk_users_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: legacy_replaced_client_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_replaced_client_banners (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    published boolean DEFAULT false NOT NULL,
    starts_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ends_at timestamp(6) with time zone DEFAULT '9999-12-31 23:59:59+00'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_banners_ends_at_after_starts_at CHECK ((ends_at > starts_at))
);


--
-- Name: legacy_replaced_client_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_replaced_client_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_replaced_client_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_replaced_client_banners_id_seq OWNED BY public.legacy_replaced_client_banners.id;


--
-- Name: legacy_replaced_client_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_replaced_client_statuses (
    id bigint NOT NULL
);


--
-- Name: legacy_replaced_client_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_replaced_client_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_replaced_client_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_replaced_client_statuses_id_seq OWNED BY public.legacy_replaced_client_statuses.id;


--
-- Name: legacy_replaced_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_replaced_clients (
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
-- Name: legacy_replaced_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_replaced_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_replaced_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_replaced_clients_id_seq OWNED BY public.legacy_replaced_clients.id;


--
-- Name: member_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.member_statuses (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: member_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.member_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_statuses_id_seq OWNED BY public.member_statuses.id;


--
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    id bigint NOT NULL,
    public_id character varying NOT NULL,
    moniker character varying,
    user_id bigint,
    division_id bigint,
    status_id bigint DEFAULT 5 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL
);


--
-- Name: members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.members_id_seq OWNED BY public.members.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    key character varying DEFAULT ''::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    organization_id bigint NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: user_client_deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_deletions (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_deletions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_deletions_id_seq OWNED BY public.user_client_deletions.id;


--
-- Name: user_client_discoveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_discoveries (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_discoveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_discoveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_discoveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_discoveries_id_seq OWNED BY public.user_client_discoveries.id;


--
-- Name: user_client_impersonations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_impersonations (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_impersonations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_impersonations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_impersonations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_impersonations_id_seq OWNED BY public.user_client_impersonations.id;


--
-- Name: user_client_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_observations (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_observations_id_seq OWNED BY public.user_client_observations.id;


--
-- Name: user_client_revocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_revocations (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_revocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_revocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_revocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_revocations_id_seq OWNED BY public.user_client_revocations.id;


--
-- Name: user_client_suspensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_client_suspensions (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_client_suspensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_client_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_client_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_client_suspensions_id_seq OWNED BY public.user_client_suspensions.id;


--
-- Name: user_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_clients (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_clients_id_seq OWNED BY public.user_clients.id;


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: apple_auths id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apple_auths ALTER COLUMN id SET DEFAULT nextval('public.apple_auths_id_seq'::regclass);


--
-- Name: client_apple_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_identities ALTER COLUMN id SET DEFAULT nextval('public.client_apple_identities_id_seq'::regclass);


--
-- Name: client_apple_identity_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_identity_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_apple_identity_statuses_id_seq'::regclass);


--
-- Name: client_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_banners ALTER COLUMN id SET DEFAULT nextval('public.client_banners_id_seq'::regclass);


--
-- Name: client_bulletins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bulletins ALTER COLUMN id SET DEFAULT nextval('public.client_bulletins_id_seq'::regclass);


--
-- Name: client_email_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_email_statuses_id_seq'::regclass);


--
-- Name: client_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails ALTER COLUMN id SET DEFAULT nextval('public.client_emails_id_seq'::regclass);


--
-- Name: client_google_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_google_identities ALTER COLUMN id SET DEFAULT nextval('public.client_google_identities_id_seq'::regclass);


--
-- Name: client_google_identity_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_google_identity_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_google_identity_statuses_id_seq'::regclass);


--
-- Name: client_member_deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions ALTER COLUMN id SET DEFAULT nextval('public.client_member_deletions_id_seq'::regclass);


--
-- Name: client_member_discoveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries ALTER COLUMN id SET DEFAULT nextval('public.client_member_discoveries_id_seq'::regclass);


--
-- Name: client_member_impersonations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations ALTER COLUMN id SET DEFAULT nextval('public.client_member_impersonations_id_seq'::regclass);


--
-- Name: client_member_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations ALTER COLUMN id SET DEFAULT nextval('public.client_member_observations_id_seq'::regclass);


--
-- Name: client_member_revocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations ALTER COLUMN id SET DEFAULT nextval('public.client_member_revocations_id_seq'::regclass);


--
-- Name: client_member_suspensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions ALTER COLUMN id SET DEFAULT nextval('public.client_member_suspensions_id_seq'::regclass);


--
-- Name: client_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members ALTER COLUMN id SET DEFAULT nextval('public.client_members_id_seq'::regclass);


--
-- Name: client_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memberships ALTER COLUMN id SET DEFAULT nextval('public.client_memberships_id_seq'::regclass);


--
-- Name: client_mfa_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_levels ALTER COLUMN id SET DEFAULT nextval('public.client_mfa_levels_id_seq'::regclass);


--
-- Name: client_mfa_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_mfa_statuses_id_seq'::regclass);


--
-- Name: client_passkey_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_passkey_statuses_id_seq'::regclass);


--
-- Name: client_passkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys ALTER COLUMN id SET DEFAULT nextval('public.client_passkeys_id_seq'::regclass);


--
-- Name: client_preference_adult_content_gate_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gate_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_adult_content_gate_options_id_seq'::regclass);


--
-- Name: client_preference_adult_content_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates ALTER COLUMN id SET DEFAULT nextval('public.client_preference_adult_content_gates_id_seq'::regclass);


--
-- Name: client_preference_currencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies ALTER COLUMN id SET DEFAULT nextval('public.client_preference_currencies_id_seq'::regclass);


--
-- Name: client_preference_currency_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currency_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_currency_options_id_seq'::regclass);


--
-- Name: client_preference_date_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_format_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_date_format_options_id_seq'::regclass);


--
-- Name: client_preference_date_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats ALTER COLUMN id SET DEFAULT nextval('public.client_preference_date_formats_id_seq'::regclass);


--
-- Name: client_preference_densities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities ALTER COLUMN id SET DEFAULT nextval('public.client_preference_densities_id_seq'::regclass);


--
-- Name: client_preference_density_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_density_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_density_options_id_seq'::regclass);


--
-- Name: client_preference_language_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_language_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_language_options_id_seq'::regclass);


--
-- Name: client_preference_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages ALTER COLUMN id SET DEFAULT nextval('public.client_preference_languages_id_seq'::regclass);


--
-- Name: client_preference_motion_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motion_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_motion_options_id_seq'::regclass);


--
-- Name: client_preference_motions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions ALTER COLUMN id SET DEFAULT nextval('public.client_preference_motions_id_seq'::regclass);


--
-- Name: client_preference_page_size_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_size_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_page_size_options_id_seq'::regclass);


--
-- Name: client_preference_page_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes ALTER COLUMN id SET DEFAULT nextval('public.client_preference_page_sizes_id_seq'::regclass);


--
-- Name: client_preference_region_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_region_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_region_options_id_seq'::regclass);


--
-- Name: client_preference_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions ALTER COLUMN id SET DEFAULT nextval('public.client_preference_regions_id_seq'::regclass);


--
-- Name: client_preference_theme_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_theme_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_theme_options_id_seq'::regclass);


--
-- Name: client_preference_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes ALTER COLUMN id SET DEFAULT nextval('public.client_preference_themes_id_seq'::regclass);


--
-- Name: client_preference_time_format_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_format_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_time_format_options_id_seq'::regclass);


--
-- Name: client_preference_time_formats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats ALTER COLUMN id SET DEFAULT nextval('public.client_preference_time_formats_id_seq'::regclass);


--
-- Name: client_preference_timezone_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezone_options ALTER COLUMN id SET DEFAULT nextval('public.client_preference_timezone_options_id_seq'::regclass);


--
-- Name: client_preference_timezones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones ALTER COLUMN id SET DEFAULT nextval('public.client_preference_timezones_id_seq'::regclass);


--
-- Name: client_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preferences ALTER COLUMN id SET DEFAULT nextval('public.client_preferences_id_seq'::regclass);


--
-- Name: client_secret_credential_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_kinds ALTER COLUMN id SET DEFAULT nextval('public.client_secret_credential_kinds_id_seq'::regclass);


--
-- Name: client_secret_credential_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_secret_credential_statuses_id_seq'::regclass);


--
-- Name: client_secret_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials ALTER COLUMN id SET DEFAULT nextval('public.client_secret_credentials_id_seq'::regclass);


--
-- Name: client_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_statuses_id_seq'::regclass);


--
-- Name: client_telephone_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_telephone_statuses_id_seq'::regclass);


--
-- Name: client_telephones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones ALTER COLUMN id SET DEFAULT nextval('public.client_telephones_id_seq'::regclass);


--
-- Name: client_totp_credential_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credential_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_totp_credential_statuses_id_seq'::regclass);


--
-- Name: client_totp_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials ALTER COLUMN id SET DEFAULT nextval('public.client_totp_credentials_id_seq'::regclass);


--
-- Name: client_visibilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_visibilities ALTER COLUMN id SET DEFAULT nextval('public.client_visibilities_id_seq'::regclass);


--
-- Name: client_withdrawal_flow_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_flow_events_id_seq'::regclass);


--
-- Name: client_withdrawal_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_flow_statuses_id_seq'::regclass);


--
-- Name: client_withdrawal_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows ALTER COLUMN id SET DEFAULT nextval('public.client_withdrawal_flows_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: legacy_replaced_client_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_banners ALTER COLUMN id SET DEFAULT nextval('public.legacy_replaced_client_banners_id_seq'::regclass);


--
-- Name: legacy_replaced_client_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_statuses ALTER COLUMN id SET DEFAULT nextval('public.legacy_replaced_client_statuses_id_seq'::regclass);


--
-- Name: legacy_replaced_clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients ALTER COLUMN id SET DEFAULT nextval('public.legacy_replaced_clients_id_seq'::regclass);


--
-- Name: member_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_statuses ALTER COLUMN id SET DEFAULT nextval('public.member_statuses_id_seq'::regclass);


--
-- Name: members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members ALTER COLUMN id SET DEFAULT nextval('public.members_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: user_client_deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions ALTER COLUMN id SET DEFAULT nextval('public.user_client_deletions_id_seq'::regclass);


--
-- Name: user_client_discoveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries ALTER COLUMN id SET DEFAULT nextval('public.user_client_discoveries_id_seq'::regclass);


--
-- Name: user_client_impersonations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations ALTER COLUMN id SET DEFAULT nextval('public.user_client_impersonations_id_seq'::regclass);


--
-- Name: user_client_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations ALTER COLUMN id SET DEFAULT nextval('public.user_client_observations_id_seq'::regclass);


--
-- Name: user_client_revocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations ALTER COLUMN id SET DEFAULT nextval('public.user_client_revocations_id_seq'::regclass);


--
-- Name: user_client_suspensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions ALTER COLUMN id SET DEFAULT nextval('public.user_client_suspensions_id_seq'::regclass);


--
-- Name: user_clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients ALTER COLUMN id SET DEFAULT nextval('public.user_clients_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: apple_auths apple_auths_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apple_auths
    ADD CONSTRAINT apple_auths_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: client_emails chk_client_emails_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_emails
    ADD CONSTRAINT chk_client_emails_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: client_passkeys chk_client_passkeys_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_passkeys
    ADD CONSTRAINT chk_client_passkeys_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: client_apple_identities chk_client_social_apples_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_apple_identities
    ADD CONSTRAINT chk_client_social_apples_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: client_google_identities chk_client_social_googles_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_google_identities
    ADD CONSTRAINT chk_client_social_googles_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: client_telephones chk_client_telephones_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_telephones
    ADD CONSTRAINT chk_client_telephones_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: clients chk_clients_mfa_requirement_consistency; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.clients
    ADD CONSTRAINT chk_clients_mfa_requirement_consistency CHECK ((((mfa_level_enabled = false) AND (mfa_level_id = 0)) OR ((mfa_level_enabled = true) AND (mfa_level_id <> 0)))) NOT VALID;


--
-- Name: clients chk_clients_terminated_requires_withdrawn; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.clients
    ADD CONSTRAINT chk_clients_terminated_requires_withdrawn CHECK (((terminated_at IS NULL) OR ((withdrawn_at IS NOT NULL) AND (withdrawn_at < 'infinity'::timestamp without time zone)))) NOT VALID;


--
-- Name: clients chk_clients_withdrawal_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.clients
    ADD CONSTRAINT chk_clients_withdrawal_order CHECK (((withdrawal_started_at IS NULL) OR (withdrawn_at IS NULL) OR (withdrawn_at = 'infinity'::timestamp without time zone) OR (withdrawal_started_at <= withdrawn_at))) NOT VALID;


--
-- Name: client_apple_identities client_apple_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_identities
    ADD CONSTRAINT client_apple_identities_pkey PRIMARY KEY (id);


--
-- Name: client_apple_identity_statuses client_apple_identity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_identity_statuses
    ADD CONSTRAINT client_apple_identity_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_banners client_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_banners
    ADD CONSTRAINT client_banners_pkey PRIMARY KEY (id);


--
-- Name: client_bulletins client_bulletins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bulletins
    ADD CONSTRAINT client_bulletins_pkey PRIMARY KEY (id);


--
-- Name: client_email_statuses client_email_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_statuses
    ADD CONSTRAINT client_email_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_emails client_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT client_emails_pkey PRIMARY KEY (id);


--
-- Name: client_google_identities client_google_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_google_identities
    ADD CONSTRAINT client_google_identities_pkey PRIMARY KEY (id);


--
-- Name: client_google_identity_statuses client_google_identity_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_google_identity_statuses
    ADD CONSTRAINT client_google_identity_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_member_deletions client_member_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions
    ADD CONSTRAINT client_member_deletions_pkey PRIMARY KEY (id);


--
-- Name: client_member_discoveries client_member_discoveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries
    ADD CONSTRAINT client_member_discoveries_pkey PRIMARY KEY (id);


--
-- Name: client_member_impersonations client_member_impersonations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations
    ADD CONSTRAINT client_member_impersonations_pkey PRIMARY KEY (id);


--
-- Name: client_member_observations client_member_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations
    ADD CONSTRAINT client_member_observations_pkey PRIMARY KEY (id);


--
-- Name: client_member_revocations client_member_revocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations
    ADD CONSTRAINT client_member_revocations_pkey PRIMARY KEY (id);


--
-- Name: client_member_suspensions client_member_suspensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions
    ADD CONSTRAINT client_member_suspensions_pkey PRIMARY KEY (id);


--
-- Name: client_members client_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members
    ADD CONSTRAINT client_members_pkey PRIMARY KEY (id);


--
-- Name: client_memberships client_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memberships
    ADD CONSTRAINT client_memberships_pkey PRIMARY KEY (id);


--
-- Name: client_mfa_levels client_mfa_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_levels
    ADD CONSTRAINT client_mfa_levels_pkey PRIMARY KEY (id);


--
-- Name: client_mfa_statuses client_mfa_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_mfa_statuses
    ADD CONSTRAINT client_mfa_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_passkey_statuses client_passkey_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_statuses
    ADD CONSTRAINT client_passkey_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_passkeys client_passkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT client_passkeys_pkey PRIMARY KEY (id);


--
-- Name: client_preference_adult_content_gate_options client_preference_adult_content_gate_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gate_options
    ADD CONSTRAINT client_preference_adult_content_gate_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_adult_content_gates client_preference_adult_content_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates
    ADD CONSTRAINT client_preference_adult_content_gates_pkey PRIMARY KEY (id);


--
-- Name: client_preference_currencies client_preference_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies
    ADD CONSTRAINT client_preference_currencies_pkey PRIMARY KEY (id);


--
-- Name: client_preference_currency_options client_preference_currency_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currency_options
    ADD CONSTRAINT client_preference_currency_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_date_format_options client_preference_date_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_format_options
    ADD CONSTRAINT client_preference_date_format_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_date_formats client_preference_date_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats
    ADD CONSTRAINT client_preference_date_formats_pkey PRIMARY KEY (id);


--
-- Name: client_preference_densities client_preference_densities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities
    ADD CONSTRAINT client_preference_densities_pkey PRIMARY KEY (id);


--
-- Name: client_preference_density_options client_preference_density_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_density_options
    ADD CONSTRAINT client_preference_density_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_language_options client_preference_language_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_language_options
    ADD CONSTRAINT client_preference_language_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_languages client_preference_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages
    ADD CONSTRAINT client_preference_languages_pkey PRIMARY KEY (id);


--
-- Name: client_preference_motion_options client_preference_motion_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motion_options
    ADD CONSTRAINT client_preference_motion_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_motions client_preference_motions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions
    ADD CONSTRAINT client_preference_motions_pkey PRIMARY KEY (id);


--
-- Name: client_preference_page_size_options client_preference_page_size_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_size_options
    ADD CONSTRAINT client_preference_page_size_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_page_sizes client_preference_page_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes
    ADD CONSTRAINT client_preference_page_sizes_pkey PRIMARY KEY (id);


--
-- Name: client_preference_region_options client_preference_region_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_region_options
    ADD CONSTRAINT client_preference_region_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_regions client_preference_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions
    ADD CONSTRAINT client_preference_regions_pkey PRIMARY KEY (id);


--
-- Name: client_preference_theme_options client_preference_theme_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_theme_options
    ADD CONSTRAINT client_preference_theme_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_themes client_preference_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes
    ADD CONSTRAINT client_preference_themes_pkey PRIMARY KEY (id);


--
-- Name: client_preference_time_format_options client_preference_time_format_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_format_options
    ADD CONSTRAINT client_preference_time_format_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_time_formats client_preference_time_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats
    ADD CONSTRAINT client_preference_time_formats_pkey PRIMARY KEY (id);


--
-- Name: client_preference_timezone_options client_preference_timezone_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezone_options
    ADD CONSTRAINT client_preference_timezone_options_pkey PRIMARY KEY (id);


--
-- Name: client_preference_timezones client_preference_timezones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones
    ADD CONSTRAINT client_preference_timezones_pkey PRIMARY KEY (id);


--
-- Name: client_preferences client_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preferences
    ADD CONSTRAINT client_preferences_pkey PRIMARY KEY (id);


--
-- Name: client_secret_credential_kinds client_secret_credential_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_kinds
    ADD CONSTRAINT client_secret_credential_kinds_pkey PRIMARY KEY (id);


--
-- Name: client_secret_credential_statuses client_secret_credential_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_statuses
    ADD CONSTRAINT client_secret_credential_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_secret_credentials client_secret_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT client_secret_credentials_pkey PRIMARY KEY (id);


--
-- Name: client_statuses client_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_statuses
    ADD CONSTRAINT client_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_telephone_statuses client_telephone_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_statuses
    ADD CONSTRAINT client_telephone_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_telephones client_telephones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT client_telephones_pkey PRIMARY KEY (id);


--
-- Name: client_totp_credential_statuses client_totp_credential_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credential_statuses
    ADD CONSTRAINT client_totp_credential_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_totp_credentials client_totp_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT client_totp_credentials_pkey PRIMARY KEY (id);


--
-- Name: client_visibilities client_visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_visibilities
    ADD CONSTRAINT client_visibilities_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_flow_events client_withdrawal_flow_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT client_withdrawal_flow_events_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_flow_statuses client_withdrawal_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_statuses
    ADD CONSTRAINT client_withdrawal_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_withdrawal_flows client_withdrawal_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT client_withdrawal_flows_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: legacy_replaced_client_banners legacy_replaced_client_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_banners
    ADD CONSTRAINT legacy_replaced_client_banners_pkey PRIMARY KEY (id);


--
-- Name: legacy_replaced_client_statuses legacy_replaced_client_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_client_statuses
    ADD CONSTRAINT legacy_replaced_client_statuses_pkey PRIMARY KEY (id);


--
-- Name: legacy_replaced_clients legacy_replaced_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT legacy_replaced_clients_pkey PRIMARY KEY (id);


--
-- Name: member_statuses member_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_statuses
    ADD CONSTRAINT member_statuses_pkey PRIMARY KEY (id);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: user_client_deletions user_client_deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions
    ADD CONSTRAINT user_client_deletions_pkey PRIMARY KEY (id);


--
-- Name: user_client_discoveries user_client_discoveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries
    ADD CONSTRAINT user_client_discoveries_pkey PRIMARY KEY (id);


--
-- Name: user_client_impersonations user_client_impersonations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations
    ADD CONSTRAINT user_client_impersonations_pkey PRIMARY KEY (id);


--
-- Name: user_client_observations user_client_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations
    ADD CONSTRAINT user_client_observations_pkey PRIMARY KEY (id);


--
-- Name: user_client_revocations user_client_revocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations
    ADD CONSTRAINT user_client_revocations_pkey PRIMARY KEY (id);


--
-- Name: user_client_suspensions user_client_suspensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions
    ADD CONSTRAINT user_client_suspensions_pkey PRIMARY KEY (id);


--
-- Name: user_clients user_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients
    ADD CONSTRAINT user_clients_pkey PRIMARY KEY (id);


--
-- Name: idx_on_client_withdrawal_flow_id_128dba0f0d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_withdrawal_flow_id_128dba0f0d ON public.client_withdrawal_flow_events USING btree (client_withdrawal_flow_id);


--
-- Name: idx_on_user_identity_secret_status_id_178d36c039; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_user_identity_secret_status_id_178d36c039 ON public.client_secret_credentials USING btree (user_identity_secret_status_id);


--
-- Name: idx_on_user_identity_totp_credential_status_id_47a8d28ad3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_user_identity_totp_credential_status_id_47a8d28ad3 ON public.client_totp_credentials USING btree (user_identity_totp_credential_status_id);


--
-- Name: index_accounts_on_accountable_type_and_accountable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_accountable_type_and_accountable_id ON public.accounts USING btree (accountable_type, accountable_id);


--
-- Name: index_accounts_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_email ON public.accounts USING btree (email);


--
-- Name: index_apple_auths_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_apple_auths_on_user_id ON public.apple_auths USING btree (user_id);


--
-- Name: index_client_apple_identities_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_apple_identities_on_discarded_at ON public.client_apple_identities USING btree (discarded_at);


--
-- Name: index_client_apple_identities_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_apple_identities_on_purged_at ON public.client_apple_identities USING btree (purged_at);


--
-- Name: index_client_apple_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_apple_identities_on_status_id ON public.client_apple_identities USING btree (status_id);


--
-- Name: index_client_apple_identities_on_token_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_apple_identities_on_token_expires_at ON public.client_apple_identities USING btree (token_expires_at);


--
-- Name: index_client_apple_identities_on_uid_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_apple_identities_on_uid_and_provider ON public.client_apple_identities USING btree (uid, provider);


--
-- Name: index_client_banners_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_banners_on_user_id ON public.client_banners USING btree (user_id);


--
-- Name: index_client_bulletins_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_bulletins_on_public_id ON public.client_bulletins USING btree (public_id);


--
-- Name: index_client_bulletins_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_bulletins_on_user_id ON public.client_bulletins USING btree (user_id);


--
-- Name: index_client_emails_on_active_address_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_emails_on_active_address_digest ON public.client_emails USING btree (address_digest) WHERE ((address_digest IS NOT NULL) AND (user_email_status_id <> 4));


--
-- Name: index_client_emails_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_discarded_at ON public.client_emails USING btree (discarded_at);


--
-- Name: index_client_emails_on_otp_last_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_otp_last_sent_at ON public.client_emails USING btree (otp_last_sent_at);


--
-- Name: index_client_emails_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_emails_on_public_id ON public.client_emails USING btree (public_id);


--
-- Name: index_client_emails_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_purged_at ON public.client_emails USING btree (purged_at);


--
-- Name: index_client_emails_on_user_email_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_user_email_status_id ON public.client_emails USING btree (user_email_status_id);


--
-- Name: index_client_emails_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_emails_on_user_id ON public.client_emails USING btree (user_id);


--
-- Name: index_client_google_identities_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_google_identities_on_discarded_at ON public.client_google_identities USING btree (discarded_at);


--
-- Name: index_client_google_identities_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_google_identities_on_purged_at ON public.client_google_identities USING btree (purged_at);


--
-- Name: index_client_google_identities_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_google_identities_on_status_id ON public.client_google_identities USING btree (status_id);


--
-- Name: index_client_google_identities_on_token_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_google_identities_on_token_expires_at ON public.client_google_identities USING btree (token_expires_at);


--
-- Name: index_client_google_identities_on_uid_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_google_identities_on_uid_and_provider ON public.client_google_identities USING btree (uid, provider);


--
-- Name: index_client_member_deletions_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_deletions_on_member_id ON public.client_member_deletions USING btree (member_id);


--
-- Name: index_client_member_deletions_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_deletions_on_user_id_and_member_id ON public.client_member_deletions USING btree (user_id, member_id);


--
-- Name: index_client_member_discoveries_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_discoveries_on_member_id ON public.client_member_discoveries USING btree (member_id);


--
-- Name: index_client_member_discoveries_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_discoveries_on_user_id_and_member_id ON public.client_member_discoveries USING btree (user_id, member_id);


--
-- Name: index_client_member_impersonations_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_impersonations_on_member_id ON public.client_member_impersonations USING btree (member_id);


--
-- Name: index_client_member_impersonations_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_impersonations_on_user_id_and_member_id ON public.client_member_impersonations USING btree (user_id, member_id);


--
-- Name: index_client_member_observations_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_observations_on_member_id ON public.client_member_observations USING btree (member_id);


--
-- Name: index_client_member_observations_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_observations_on_user_id_and_member_id ON public.client_member_observations USING btree (user_id, member_id);


--
-- Name: index_client_member_revocations_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_revocations_on_member_id ON public.client_member_revocations USING btree (member_id);


--
-- Name: index_client_member_revocations_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_revocations_on_user_id_and_member_id ON public.client_member_revocations USING btree (user_id, member_id);


--
-- Name: index_client_member_suspensions_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_member_suspensions_on_member_id ON public.client_member_suspensions USING btree (member_id);


--
-- Name: index_client_member_suspensions_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_member_suspensions_on_user_id_and_member_id ON public.client_member_suspensions USING btree (user_id, member_id);


--
-- Name: index_client_members_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_members_on_member_id ON public.client_members USING btree (member_id);


--
-- Name: index_client_members_on_user_id_and_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_members_on_user_id_and_member_id ON public.client_members USING btree (user_id, member_id);


--
-- Name: index_client_memberships_on_user_id_and_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_memberships_on_user_id_and_workspace_id ON public.client_memberships USING btree (user_id, workspace_id);


--
-- Name: index_client_memberships_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_memberships_on_workspace_id ON public.client_memberships USING btree (workspace_id);


--
-- Name: index_client_passkeys_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkeys_on_discarded_at ON public.client_passkeys USING btree (discarded_at);


--
-- Name: index_client_passkeys_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkeys_on_public_id ON public.client_passkeys USING btree (public_id);


--
-- Name: index_client_passkeys_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkeys_on_purged_at ON public.client_passkeys USING btree (purged_at);


--
-- Name: index_client_passkeys_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkeys_on_status_id ON public.client_passkeys USING btree (status_id);


--
-- Name: index_client_passkeys_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkeys_on_webauthn_id ON public.client_passkeys USING btree (webauthn_id);


--
-- Name: index_client_preference_adult_content_gates_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_adult_content_gates_on_option_id ON public.client_preference_adult_content_gates USING btree (option_id);


--
-- Name: index_client_preference_adult_content_gates_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_adult_content_gates_on_preference_id ON public.client_preference_adult_content_gates USING btree (preference_id);


--
-- Name: index_client_preference_currencies_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_currencies_on_option_id ON public.client_preference_currencies USING btree (option_id);


--
-- Name: index_client_preference_currencies_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_currencies_on_preference_id ON public.client_preference_currencies USING btree (preference_id);


--
-- Name: index_client_preference_date_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_date_formats_on_option_id ON public.client_preference_date_formats USING btree (option_id);


--
-- Name: index_client_preference_date_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_date_formats_on_preference_id ON public.client_preference_date_formats USING btree (preference_id);


--
-- Name: index_client_preference_densities_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_densities_on_option_id ON public.client_preference_densities USING btree (option_id);


--
-- Name: index_client_preference_densities_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_densities_on_preference_id ON public.client_preference_densities USING btree (preference_id);


--
-- Name: index_client_preference_languages_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_languages_on_option_id ON public.client_preference_languages USING btree (option_id);


--
-- Name: index_client_preference_languages_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_languages_on_preference_id ON public.client_preference_languages USING btree (preference_id);


--
-- Name: index_client_preference_motions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_motions_on_option_id ON public.client_preference_motions USING btree (option_id);


--
-- Name: index_client_preference_motions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_motions_on_preference_id ON public.client_preference_motions USING btree (preference_id);


--
-- Name: index_client_preference_page_sizes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_page_sizes_on_option_id ON public.client_preference_page_sizes USING btree (option_id);


--
-- Name: index_client_preference_page_sizes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_page_sizes_on_preference_id ON public.client_preference_page_sizes USING btree (preference_id);


--
-- Name: index_client_preference_regions_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_regions_on_option_id ON public.client_preference_regions USING btree (option_id);


--
-- Name: index_client_preference_regions_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_regions_on_preference_id ON public.client_preference_regions USING btree (preference_id);


--
-- Name: index_client_preference_themes_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_themes_on_option_id ON public.client_preference_themes USING btree (option_id);


--
-- Name: index_client_preference_themes_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_themes_on_preference_id ON public.client_preference_themes USING btree (preference_id);


--
-- Name: index_client_preference_time_formats_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_time_formats_on_option_id ON public.client_preference_time_formats USING btree (option_id);


--
-- Name: index_client_preference_time_formats_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_time_formats_on_preference_id ON public.client_preference_time_formats USING btree (preference_id);


--
-- Name: index_client_preference_timezones_on_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_preference_timezones_on_option_id ON public.client_preference_timezones USING btree (option_id);


--
-- Name: index_client_preference_timezones_on_preference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preference_timezones_on_preference_id ON public.client_preference_timezones USING btree (preference_id);


--
-- Name: index_client_preferences_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preferences_on_public_id ON public.client_preferences USING btree (public_id);


--
-- Name: index_client_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_preferences_on_user_id ON public.client_preferences USING btree (user_id);


--
-- Name: index_client_secret_credentials_on_lookup_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_credentials_on_lookup_digest ON public.client_secret_credentials USING btree (lookup_digest);


--
-- Name: index_client_secret_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_secret_credentials_on_public_id ON public.client_secret_credentials USING btree (public_id);


--
-- Name: index_client_secret_credentials_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_credentials_on_user_id ON public.client_secret_credentials USING btree (user_id);


--
-- Name: index_client_secret_credentials_on_user_secret_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_secret_credentials_on_user_secret_kind_id ON public.client_secret_credentials USING btree (user_secret_kind_id);


--
-- Name: index_client_telephones_on_active_number_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephones_on_active_number_digest ON public.client_telephones USING btree (number_digest) WHERE ((number_digest IS NOT NULL) AND (user_identity_telephone_status_id <> 4));


--
-- Name: index_client_telephones_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_discarded_at ON public.client_telephones USING btree (discarded_at);


--
-- Name: index_client_telephones_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephones_on_public_id ON public.client_telephones USING btree (public_id);


--
-- Name: index_client_telephones_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_purged_at ON public.client_telephones USING btree (purged_at);


--
-- Name: index_client_telephones_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_user_id ON public.client_telephones USING btree (user_id);


--
-- Name: index_client_telephones_on_user_identity_telephone_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephones_on_user_identity_telephone_status_id ON public.client_telephones USING btree (user_identity_telephone_status_id);


--
-- Name: index_client_totp_credentials_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_credentials_on_public_id ON public.client_totp_credentials USING btree (public_id);


--
-- Name: index_client_totp_credentials_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_totp_credentials_on_user_id ON public.client_totp_credentials USING btree (user_id);


--
-- Name: index_client_withdrawal_flow_events_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_client_id ON public.client_withdrawal_flow_events USING btree (client_id);


--
-- Name: index_client_withdrawal_flow_events_on_from_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_from_status_id ON public.client_withdrawal_flow_events USING btree (from_status_id);


--
-- Name: index_client_withdrawal_flow_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_occurred_at ON public.client_withdrawal_flow_events USING btree (occurred_at);


--
-- Name: index_client_withdrawal_flow_events_on_to_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flow_events_on_to_status_id ON public.client_withdrawal_flow_events USING btree (to_status_id);


--
-- Name: index_client_withdrawal_flows_on_began_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_began_at ON public.client_withdrawal_flows USING btree (began_at);


--
-- Name: index_client_withdrawal_flows_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_client_id ON public.client_withdrawal_flows USING btree (client_id);


--
-- Name: index_client_withdrawal_flows_on_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_completed_at ON public.client_withdrawal_flows USING btree (completed_at);


--
-- Name: index_client_withdrawal_flows_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_discarded_at ON public.client_withdrawal_flows USING btree (discarded_at);


--
-- Name: index_client_withdrawal_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_withdrawal_flows_on_public_id ON public.client_withdrawal_flows USING btree (public_id);


--
-- Name: index_client_withdrawal_flows_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_purged_at ON public.client_withdrawal_flows USING btree (purged_at);


--
-- Name: index_client_withdrawal_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_withdrawal_flows_on_status_id ON public.client_withdrawal_flows USING btree (status_id);


--
-- Name: index_clients_on_access_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_access_state ON public.clients USING btree (access_state);


--
-- Name: index_clients_on_admin_locked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_admin_locked_at ON public.clients USING btree (admin_locked_at) WHERE (admin_locked_at IS NOT NULL);


--
-- Name: index_clients_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_deactivated_at ON public.clients USING btree (deactivated_at) WHERE (deactivated_at IS NOT NULL);


--
-- Name: index_clients_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_discarded_at ON public.clients USING btree (discarded_at);


--
-- Name: index_clients_on_mfa_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_mfa_level_id ON public.clients USING btree (mfa_level_id);


--
-- Name: index_clients_on_mfa_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_mfa_status_id ON public.clients USING btree (mfa_status_id);


--
-- Name: index_clients_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_public_id ON public.clients USING btree (public_id);


--
-- Name: index_clients_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_purged_at ON public.clients USING btree (purged_at) WHERE (purged_at IS NOT NULL);


--
-- Name: index_clients_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_status_id ON public.clients USING btree (status_id);


--
-- Name: index_clients_on_terminated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_terminated_at ON public.clients USING btree (terminated_at) WHERE (terminated_at IS NOT NULL);


--
-- Name: index_clients_on_token_valid_after_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_token_valid_after_at ON public.clients USING btree (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL);


--
-- Name: index_clients_on_visibility_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_visibility_id ON public.clients USING btree (visibility_id);


--
-- Name: index_clients_on_withdrawal_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_withdrawal_started_at ON public.clients USING btree (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL);


--
-- Name: index_clients_on_withdrawn_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_withdrawn_at ON public.clients USING btree (withdrawn_at) WHERE (withdrawn_at IS NOT NULL);


--
-- Name: index_legacy_replaced_client_banners_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_client_banners_on_client_id ON public.legacy_replaced_client_banners USING btree (client_id);


--
-- Name: index_legacy_replaced_clients_on_client_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_client_status_id ON public.legacy_replaced_clients USING btree (client_status_id);


--
-- Name: index_legacy_replaced_clients_on_division_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_division_id ON public.legacy_replaced_clients USING btree (division_id);


--
-- Name: index_legacy_replaced_clients_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_legacy_replaced_clients_on_public_id ON public.legacy_replaced_clients USING btree (public_id);


--
-- Name: index_legacy_replaced_clients_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_status_id ON public.legacy_replaced_clients USING btree (status_id);


--
-- Name: index_legacy_replaced_clients_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_replaced_clients_on_user_id ON public.legacy_replaced_clients USING btree (user_id);


--
-- Name: index_members_on_division_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_division_id ON public.members USING btree (division_id);


--
-- Name: index_members_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_members_on_public_id ON public.members USING btree (public_id);


--
-- Name: index_members_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_purged_at ON public.members USING btree (purged_at);


--
-- Name: index_members_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_status_id ON public.members USING btree (status_id);


--
-- Name: index_members_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_user_id ON public.members USING btree (user_id);


--
-- Name: index_roles_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_organization_id ON public.roles USING btree (organization_id);


--
-- Name: index_user_client_deletions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_deletions_on_client_id ON public.user_client_deletions USING btree (client_id);


--
-- Name: index_user_client_deletions_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_deletions_on_user_id_and_client_id ON public.user_client_deletions USING btree (user_id, client_id);


--
-- Name: index_user_client_discoveries_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_discoveries_on_client_id ON public.user_client_discoveries USING btree (client_id);


--
-- Name: index_user_client_discoveries_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_discoveries_on_user_id_and_client_id ON public.user_client_discoveries USING btree (user_id, client_id);


--
-- Name: index_user_client_impersonations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_impersonations_on_client_id ON public.user_client_impersonations USING btree (client_id);


--
-- Name: index_user_client_impersonations_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_impersonations_on_user_id_and_client_id ON public.user_client_impersonations USING btree (user_id, client_id);


--
-- Name: index_user_client_observations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_observations_on_client_id ON public.user_client_observations USING btree (client_id);


--
-- Name: index_user_client_observations_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_observations_on_user_id_and_client_id ON public.user_client_observations USING btree (user_id, client_id);


--
-- Name: index_user_client_revocations_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_revocations_on_client_id ON public.user_client_revocations USING btree (client_id);


--
-- Name: index_user_client_revocations_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_revocations_on_user_id_and_client_id ON public.user_client_revocations USING btree (user_id, client_id);


--
-- Name: index_user_client_suspensions_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_client_suspensions_on_client_id ON public.user_client_suspensions USING btree (client_id);


--
-- Name: index_user_client_suspensions_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_client_suspensions_on_user_id_and_client_id ON public.user_client_suspensions USING btree (user_id, client_id);


--
-- Name: index_user_clients_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_clients_on_client_id ON public.user_clients USING btree (client_id);


--
-- Name: index_user_clients_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_clients_on_user_id_and_client_id ON public.user_clients USING btree (user_id, client_id);


--
-- Name: index_user_identity_passkeys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_identity_passkeys_on_user_id ON public.client_passkeys USING btree (user_id);


--
-- Name: index_user_identity_social_apples_on_user_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_identity_social_apples_on_user_id_unique ON public.client_apple_identities USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_user_identity_social_googles_on_user_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_identity_social_googles_on_user_id_unique ON public.client_google_identities USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: legacy_replaced_clients fk_clients_on_client_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_clients_on_client_status_id FOREIGN KEY (client_status_id) REFERENCES public.legacy_replaced_client_statuses(id);


--
-- Name: legacy_replaced_clients fk_clients_on_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_clients_on_status_id FOREIGN KEY (status_id) REFERENCES public.legacy_replaced_client_statuses(id);


--
-- Name: client_passkeys fk_rails_0095e1bdca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT fk_rails_0095e1bdca FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preference_densities fk_rails_010ff0dcc1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities
    ADD CONSTRAINT fk_rails_010ff0dcc1 FOREIGN KEY (option_id) REFERENCES public.client_preference_density_options(id);


--
-- Name: client_banners fk_rails_08c770fdce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_banners
    ADD CONSTRAINT fk_rails_08c770fdce FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_suspensions fk_rails_0f76328e35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions
    ADD CONSTRAINT fk_rails_0f76328e35 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_preference_date_formats fk_rails_0fb3559373; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats
    ADD CONSTRAINT fk_rails_0fb3559373 FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_emails fk_rails_15a0bdccd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT fk_rails_15a0bdccd5 FOREIGN KEY (user_email_status_id) REFERENCES public.client_email_statuses(id);


--
-- Name: client_preference_motions fk_rails_1d88bfb57f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions
    ADD CONSTRAINT fk_rails_1d88bfb57f FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_secret_credentials fk_rails_1dae7ac648; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_1dae7ac648 FOREIGN KEY (user_identity_secret_status_id) REFERENCES public.client_secret_credential_statuses(id);


--
-- Name: user_clients fk_rails_1ff22d5fc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients
    ADD CONSTRAINT fk_rails_1ff22d5fc3 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id) ON DELETE CASCADE;


--
-- Name: client_preference_time_formats fk_rails_21483998fe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats
    ADD CONSTRAINT fk_rails_21483998fe FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: legacy_replaced_clients fk_rails_21c421fd41; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_rails_21c421fd41 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: client_preference_currencies fk_rails_250ae85286; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies
    ADD CONSTRAINT fk_rails_250ae85286 FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: members fk_rails_2e88fb7ce9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_2e88fb7ce9 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: client_google_identities fk_rails_2e9d0c19b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_google_identities
    ADD CONSTRAINT fk_rails_2e9d0c19b0 FOREIGN KEY (status_id) REFERENCES public.client_google_identity_statuses(id);


--
-- Name: client_preference_time_formats fk_rails_316f4ec31e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_time_formats
    ADD CONSTRAINT fk_rails_316f4ec31e FOREIGN KEY (option_id) REFERENCES public.client_preference_time_format_options(id);


--
-- Name: client_preference_date_formats fk_rails_31ba154e7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_date_formats
    ADD CONSTRAINT fk_rails_31ba154e7f FOREIGN KEY (option_id) REFERENCES public.client_preference_date_format_options(id);


--
-- Name: user_client_deletions fk_rails_38cf70f5c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions
    ADD CONSTRAINT fk_rails_38cf70f5c0 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preferences fk_rails_39373ef225; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preferences
    ADD CONSTRAINT fk_rails_39373ef225 FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_preference_currencies fk_rails_3996e38113; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_currencies
    ADD CONSTRAINT fk_rails_3996e38113 FOREIGN KEY (option_id) REFERENCES public.client_preference_currency_options(id);


--
-- Name: client_withdrawal_flows fk_rails_3a897cfb78; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT fk_rails_3a897cfb78 FOREIGN KEY (status_id) REFERENCES public.client_withdrawal_flow_statuses(id) NOT VALID;


--
-- Name: client_member_deletions fk_rails_3d604b095f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions
    ADD CONSTRAINT fk_rails_3d604b095f FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_emails fk_rails_410ac92848; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_emails
    ADD CONSTRAINT fk_rails_410ac92848 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_members fk_rails_4549b9cedb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members
    ADD CONSTRAINT fk_rails_4549b9cedb FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: client_member_discoveries fk_rails_4a028721b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries
    ADD CONSTRAINT fk_rails_4a028721b4 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_secret_credentials fk_rails_4ab5f45eae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_4ab5f45eae FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_totp_credentials fk_rails_5146d3e196; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT fk_rails_5146d3e196 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_member_suspensions fk_rails_59ba0ab07d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions
    ADD CONSTRAINT fk_rails_59ba0ab07d FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_member_deletions fk_rails_5a97c3e343; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_deletions
    ADD CONSTRAINT fk_rails_5a97c3e343 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_deletions fk_rails_5c75a5e7b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_deletions
    ADD CONSTRAINT fk_rails_5c75a5e7b0 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: user_client_observations fk_rails_61e7ab5f14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations
    ADD CONSTRAINT fk_rails_61e7ab5f14 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_discoveries fk_rails_64edfa59fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries
    ADD CONSTRAINT fk_rails_64edfa59fc FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: clients fk_rails_67ec2e6839; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_67ec2e6839 FOREIGN KEY (mfa_status_id) REFERENCES public.client_mfa_statuses(id);


--
-- Name: client_member_impersonations fk_rails_7148fa7540; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations
    ADD CONSTRAINT fk_rails_7148fa7540 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_member_revocations fk_rails_7311994ef4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations
    ADD CONSTRAINT fk_rails_7311994ef4 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_withdrawal_flow_events fk_rails_7344701780; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_7344701780 FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE NOT VALID;


--
-- Name: clients fk_rails_73fa0fcaee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_73fa0fcaee FOREIGN KEY (mfa_level_id) REFERENCES public.client_mfa_levels(id);


--
-- Name: client_apple_identities fk_rails_779a7e522b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_identities
    ADD CONSTRAINT fk_rails_779a7e522b FOREIGN KEY (status_id) REFERENCES public.client_apple_identity_statuses(id);


--
-- Name: client_member_revocations fk_rails_7be747ff66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_revocations
    ADD CONSTRAINT fk_rails_7be747ff66 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_telephones fk_rails_7d903b3fd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT fk_rails_7d903b3fd3 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_revocations fk_rails_7fd74473b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations
    ADD CONSTRAINT fk_rails_7fd74473b8 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_member_observations fk_rails_80174a8986; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations
    ADD CONSTRAINT fk_rails_80174a8986 FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_secret_credentials fk_rails_85ad49373c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credentials
    ADD CONSTRAINT fk_rails_85ad49373c FOREIGN KEY (user_secret_kind_id) REFERENCES public.client_secret_credential_kinds(id);


--
-- Name: client_apple_identities fk_rails_86cd98ea8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_apple_identities
    ADD CONSTRAINT fk_rails_86cd98ea8f FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preference_page_sizes fk_rails_8c10421fba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes
    ADD CONSTRAINT fk_rails_8c10421fba FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_adult_content_gates fk_rails_8e51082240; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_8e51082240 FOREIGN KEY (option_id) REFERENCES public.client_preference_adult_content_gate_options(id);


--
-- Name: legacy_replaced_clients fk_rails_910109bee1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_replaced_clients
    ADD CONSTRAINT fk_rails_910109bee1 FOREIGN KEY (client_status_id) REFERENCES public.legacy_replaced_client_statuses(id);


--
-- Name: client_preference_densities fk_rails_92ff4cec37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_densities
    ADD CONSTRAINT fk_rails_92ff4cec37 FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_member_discoveries fk_rails_93b97b3c26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_discoveries
    ADD CONSTRAINT fk_rails_93b97b3c26 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_withdrawal_flow_events fk_rails_9511d96f8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_9511d96f8c FOREIGN KEY (to_status_id) REFERENCES public.client_withdrawal_flow_statuses(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: client_member_observations fk_rails_951fe9a437; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_observations
    ADD CONSTRAINT fk_rails_951fe9a437 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: members fk_rails_958fda1156; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_958fda1156 FOREIGN KEY (status_id) REFERENCES public.member_statuses(id);


--
-- Name: client_google_identities fk_rails_96706c4d26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_google_identities
    ADD CONSTRAINT fk_rails_96706c4d26 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preference_page_sizes fk_rails_991df7332c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_page_sizes
    ADD CONSTRAINT fk_rails_991df7332c FOREIGN KEY (option_id) REFERENCES public.client_preference_page_size_options(id);


--
-- Name: user_client_suspensions fk_rails_9bd8ae64a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_suspensions
    ADD CONSTRAINT fk_rails_9bd8ae64a6 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_impersonations fk_rails_a7f1ca79fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations
    ADD CONSTRAINT fk_rails_a7f1ca79fd FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_discoveries fk_rails_a8523d9333; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_discoveries
    ADD CONSTRAINT fk_rails_a8523d9333 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_impersonations fk_rails_b0deaee0e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_impersonations
    ADD CONSTRAINT fk_rails_b0deaee0e3 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_withdrawal_flow_events fk_rails_b55e5a56c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_b55e5a56c4 FOREIGN KEY (client_withdrawal_flow_id) REFERENCES public.client_withdrawal_flows(id) NOT VALID;


--
-- Name: client_telephones fk_rails_c81d47bc96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephones
    ADD CONSTRAINT fk_rails_c81d47bc96 FOREIGN KEY (user_identity_telephone_status_id) REFERENCES public.client_telephone_statuses(id);


--
-- Name: clients fk_rails_c9df50d461; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_c9df50d461 FOREIGN KEY (visibility_id) REFERENCES public.client_visibilities(id);


--
-- Name: clients fk_rails_ce4a327a04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_ce4a327a04 FOREIGN KEY (status_id) REFERENCES public.client_statuses(id);


--
-- Name: client_bulletins fk_rails_cedaf1b735; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bulletins
    ADD CONSTRAINT fk_rails_cedaf1b735 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_members fk_rails_d1678b342d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_members
    ADD CONSTRAINT fk_rails_d1678b342d FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_preference_adult_content_gates fk_rails_db31dff0ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_adult_content_gates
    ADD CONSTRAINT fk_rails_db31dff0ff FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: apple_auths fk_rails_db7b8ce293; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apple_auths
    ADD CONSTRAINT fk_rails_db7b8ce293 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_clients fk_rails_dd94a5910e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_clients
    ADD CONSTRAINT fk_rails_dd94a5910e FOREIGN KEY (user_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_withdrawal_flows fk_rails_e5e99fd372; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flows
    ADD CONSTRAINT fk_rails_e5e99fd372 FOREIGN KEY (client_id) REFERENCES public.clients(id) NOT VALID;


--
-- Name: client_memberships fk_rails_e670a4dd3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_memberships
    ADD CONSTRAINT fk_rails_e670a4dd3b FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_member_impersonations fk_rails_ec8f1933d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_impersonations
    ADD CONSTRAINT fk_rails_ec8f1933d6 FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: user_client_observations fk_rails_ed2cc58750; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_observations
    ADD CONSTRAINT fk_rails_ed2cc58750 FOREIGN KEY (client_id) REFERENCES public.legacy_replaced_clients(id);


--
-- Name: client_totp_credentials fk_rails_ee2c1859b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_credentials
    ADD CONSTRAINT fk_rails_ee2c1859b3 FOREIGN KEY (user_identity_totp_credential_status_id) REFERENCES public.client_totp_credential_statuses(id);


--
-- Name: client_member_suspensions fk_rails_f0f64ec73d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_member_suspensions
    ADD CONSTRAINT fk_rails_f0f64ec73d FOREIGN KEY (member_id) REFERENCES public.members(id);


--
-- Name: client_withdrawal_flow_events fk_rails_f24d4919a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_withdrawal_flow_events
    ADD CONSTRAINT fk_rails_f24d4919a7 FOREIGN KEY (from_status_id) REFERENCES public.client_withdrawal_flow_statuses(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: client_preference_motions fk_rails_f49048bc2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_motions
    ADD CONSTRAINT fk_rails_f49048bc2b FOREIGN KEY (option_id) REFERENCES public.client_preference_motion_options(id);


--
-- Name: client_passkeys fk_rails_f5e90919e8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkeys
    ADD CONSTRAINT fk_rails_f5e90919e8 FOREIGN KEY (status_id) REFERENCES public.client_passkey_statuses(id);


--
-- Name: user_client_revocations fk_rails_fdc3477c5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_client_revocations
    ADD CONSTRAINT fk_rails_fdc3477c5a FOREIGN KEY (user_id) REFERENCES public.clients(id);


--
-- Name: client_preference_languages fk_user_preference_languages_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages
    ADD CONSTRAINT fk_user_preference_languages_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_language_options(id);


--
-- Name: client_preference_languages fk_user_preference_languages_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_languages
    ADD CONSTRAINT fk_user_preference_languages_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_regions fk_user_preference_regions_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions
    ADD CONSTRAINT fk_user_preference_regions_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_region_options(id);


--
-- Name: client_preference_regions fk_user_preference_regions_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_regions
    ADD CONSTRAINT fk_user_preference_regions_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_themes fk_user_preference_themes_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes
    ADD CONSTRAINT fk_user_preference_themes_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_theme_options(id);


--
-- Name: client_preference_themes fk_user_preference_themes_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_themes
    ADD CONSTRAINT fk_user_preference_themes_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- Name: client_preference_timezones fk_user_preference_timezones_on_option_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones
    ADD CONSTRAINT fk_user_preference_timezones_on_option_id FOREIGN KEY (option_id) REFERENCES public.client_preference_timezone_options(id);


--
-- Name: client_preference_timezones fk_user_preference_timezones_on_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_preference_timezones
    ADD CONSTRAINT fk_user_preference_timezones_on_preference_id FOREIGN KEY (preference_id) REFERENCES public.client_preferences(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260623100000'),
('20260620123000'),
('20260616150010'),
('20260616150005'),
('20260614090001'),
('20260614090000'),
('20260612100000'),
('20260530032500'),
('20260530032400'),
('20260530032300'),
('20260530032100'),
('20260530032000'),
('20260530031000'),
('20260528162000'),
('20260526090000'),
('20260525200000'),
('20260525131000'),
('20260525120000'),
('20260520143000'),
('20260519172001'),
('20260519094000'),
('20260518181000'),
('20260518180002'),
('20260518180001'),
('20260518180000'),
('20260518170001'),
('20260518170000'),
('20260518163000'),
('20260518120001'),
('20260518120000'),
('20260518085551'),
('20260514143000'),
('20260514140000'),
('20260514100000'),
('20260514063700'),
('20260514062000'),
('20260513161000'),
('20260513153000'),
('20260513122000'),
('20260513120000'),
('20260512120000'),
('20260512110000'),
('20260512103000'),
('20260512102000'),
('20260512101000'),
('20260512100000'),
('20260508202200'),
('20260508151000'),
('20260508140999'),
('20260508140930'),
('20260508135007'),
('20260508135006'),
('20260507000007'),
('20260507000006'),
('20260507000005'),
('20260507000004'),
('20260507000003'),
('20260507000001'),
('20260506210900'),
('20260330000000'),
('20260329150500'),
('20260329084515'),
('20260323013703'),
('20260322100000'),
('20260319125137'),
('20260318050103'),
('20260318050102'),
('20260318035439'),
('20260312200000'),
('20260309000001'),
('20260307121000'),
('20260307120000'),
('20260305114353'),
('20260305114343'),
('20260305114342'),
('20260305114341'),
('20260305114340'),
('20260305114339'),
('20260305114338'),
('20260305114337'),
('20260305114336'),
('20260305114335'),
('20260226150000'),
('20260226130000'),
('20260226100000'),
('20260224170000'),
('20260213150000'),
('20260213010000'),
('20260212000001'),
('20260210123000'),
('20260210120000'),
('20260210100000'),
('20260209090000'),
('20260208193000'),
('20260208180000'),
('20260208170000'),
('20260208152950'),
('20260206120000'),
('20260205150000'),
('20260205140539'),
('20260204170000'),
('20260204160000'),
('20260204150845'),
('20260204133256'),
('20260204133143'),
('20260203172000'),
('20260203160000'),
('20260202260000'),
('20260202250001'),
('20260202250000'),
('20260202230000'),
('20260202220000'),
('20260202210000'),
('20260202200100'),
('20260202200000'),
('20260202185000'),
('20260202160000'),
('20260201214420'),
('20260201210004'),
('20260201190008'),
('20260131149000'),
('20260131140011'),
('20260131140010'),
('20260131140009'),
('20260131140008'),
('20260131140007'),
('20260131140006'),
('20260131140005'),
('20260131140004'),
('20260131140003'),
('20260131140002'),
('20260131140001'),
('20260131140000'),
('20260130130002'),
('20260130114404'),
('20260124174000'),
('20260123172135'),
('20260123162700'),
('20260122100002'),
('20260122100000'),
('20260121184557'),
('20260121084849'),
('20260121083250'),
('20260121083248'),
('20260121083246'),
('20260121000001'),
('20260121000000'),
('20260119051226'),
('20260115120000'),
('20260114120221'),
('20260111120000'),
('20260110194100'),
('20260109141212'),
('20260108100600'),
('20260106120000'),
('20260106110000'),
('20260105150000'),
('20260103122036'),
('20260102100034'),
('20260102100033'),
('20260102100032'),
('20260102100031'),
('20260102100030'),
('20260102100029'),
('20260102100028'),
('20260102100025'),
('20260102100024'),
('20260102100023'),
('20260102100022'),
('20260102100021'),
('20260102100020'),
('20260102100015'),
('20260102100012'),
('20260102100008'),
('20260102100001'),
('20260102100000'),
('20260102091045'),
('20260102080321'),
('20260102080314'),
('20260102080308'),
('20260102080302'),
('20260102080255'),
('20260102080241'),
('20260102035039'),
('20260102035038'),
('20260102035008'),
('20251230170005'),
('20251230150021'),
('20251230150010'),
('20251230145346'),
('20251230145332'),
('20251230140819'),
('20251230133000'),
('20251230120001'),
('20251230093100'),
('20251230072244'),
('20251230072243'),
('20251230072242'),
('20251230072235'),
('20251230072105'),
('20251230010100'),
('20251227230020'),
('20251227223116'),
('20251226020999'),
('20251226013000'),
('20251226000001'),
('20251225213914'),
('20251225183101'),
('20251225000000'),
('20251224190010'),
('20251224190001'),
('20251224184759'),
('20251224173428'),
('20251224173000'),
('20251224172000'),
('20251224171000'),
('20251224170000'),
('20251224164000'),
('20251224163000'),
('20251224162000'),
('20251224161000'),
('20251224154201'),
('20251224152201'),
('20251224140101'),
('20251224130001'),
('20251224123201'),
('20251224122001'),
('20251222213000'),
('20251222212000'),
('20251222205830'),
('20251221134000'),
('20251221133001'),
('20251221130000'),
('20251221120000'),
('20251220185352'),
('20251218150000'),
('20251218141000'),
('20251218120013'),
('20251218120012'),
('20251218120011'),
('20251218120010'),
('20251216132111'),
('20251216131717'),
('20251214141739'),
('20251214133950'),
('20251214133800'),
('20251213160233'),
('20251213154426'),
('20251213153719'),
('20251212163549'),
('20251212163547'),
('20251212163546'),
('20251212163545'),
('20251212163543'),
('20251212163542'),
('20251212163539'),
('20251212163538'),
('20251212163537'),
('20251212163536'),
('20251212163535'),
('20251212163534'),
('20251212163533'),
('20251212163532'),
('20251211170000'),
('20251211163810'),
('20251211163754'),
('20251211163301'),
('20251211163246'),
('20251211100100'),
('20251211100000'),
('20251211081312'),
('20251209143001'),
('20251209123000'),
('20251209020001'),
('20251209014633'),
('20251208230201'),
('20251208230102'),
('20251208223048'),
('20251208211448'),
('20251208210540'),
('20251208054613'),
('20251115084000'),
('20251115081000'),
('20251115080000'),
('20251115076000'),
('20251115075000'),
('20251115074000'),
('20251115072000'),
('20251115070000'),
('20251115061000'),
('20251114051724'),
('20250808064814'),
('20250803215056'),
('20250803215016'),
('20250801193448'),
('20250429234642'),
('20250429231842'),
('20250421131400'),
('20240830171643'),
('20240830171634'),
('20240827130201'),
('20240627130203');

