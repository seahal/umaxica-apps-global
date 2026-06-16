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
-- Name: client_authorization_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_authorization_codes (
    id bigint NOT NULL,
    acr character varying,
    auth_method character varying,
    client_id character varying(64) NOT NULL,
    code character varying(64) NOT NULL,
    code_challenge character varying NOT NULL,
    code_challenge_method character varying(8) DEFAULT 'S256'::character varying NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    nonce character varying,
    redirect_uri text NOT NULL,
    scope character varying,
    user_id bigint NOT NULL,
    state character varying,
    updated_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_user_authorization_codes_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: client_authorization_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_authorization_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_authorization_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_authorization_codes_id_seq OWNED BY public.client_authorization_codes.id;


--
-- Name: client_device_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_device_sessions (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    user_id bigint NOT NULL,
    dbsc_session_id_digest character varying,
    dbsc_public_key_thumbprint character varying,
    dbsc_bound_at timestamp(6) with time zone,
    dpop_jkt character varying,
    status_id bigint DEFAULT 1 NOT NULL,
    current_refresh_token_id bigint,
    refresh_token_family_id character varying,
    last_seen_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    revoke_reason character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_network_hmac character varying
);


--
-- Name: client_device_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_device_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_device_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_device_sessions_id_seq OWNED BY public.client_device_sessions.id;


--
-- Name: client_dpop_proof_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_dpop_proof_states (
    id bigint NOT NULL,
    jti character varying,
    jkt character varying,
    nonce character varying,
    htm character varying,
    htu character varying,
    seen_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    nonce_used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_dpop_proof_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_dpop_proof_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_dpop_proof_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_dpop_proof_states_id_seq OWNED BY public.client_dpop_proof_states.id;


--
-- Name: client_email_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_email_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    email_candidate_ref character varying,
    normalized_email_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_email_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_email_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_email_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_email_ceremony_transactions_id_seq OWNED BY public.client_email_ceremony_transactions.id;


--
-- Name: client_oauth_callback_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oauth_callback_states (
    id bigint NOT NULL,
    state_digest character varying NOT NULL,
    provider character varying NOT NULL,
    intent character varying,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_oauth_callback_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oauth_callback_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oauth_callback_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oauth_callback_states_id_seq OWNED BY public.client_oauth_callback_states.id;


--
-- Name: client_oidc_authorization_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oidc_authorization_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    intent character varying NOT NULL,
    client_id character varying NOT NULL,
    redirect_uri character varying NOT NULL,
    response_type character varying NOT NULL,
    scope character varying NOT NULL,
    state character varying NOT NULL,
    nonce character varying NOT NULL,
    code_challenge character varying NOT NULL,
    code_challenge_method character varying NOT NULL,
    login_challenge character varying NOT NULL,
    login_challenge_expires_at timestamp(6) with time zone NOT NULL,
    authenticated_at timestamp(6) with time zone,
    actor_ref character varying,
    session_ref character varying,
    auth_method character varying,
    acr character varying,
    consumed_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    status character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_oidc_authorization_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oidc_authorization_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oidc_authorization_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oidc_authorization_transactions_id_seq OWNED BY public.client_oidc_authorization_transactions.id;


--
-- Name: client_oidc_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_oidc_connections (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    user_id bigint NOT NULL,
    client_id character varying(64) NOT NULL,
    scope character varying,
    last_used_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_oidc_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_oidc_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_oidc_connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_oidc_connections_id_seq OWNED BY public.client_oidc_connections.id;


--
-- Name: client_passkey_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_passkey_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_passkey_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_passkey_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_passkey_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_passkey_ceremony_transactions_id_seq OWNED BY public.client_passkey_ceremony_transactions.id;


--
-- Name: client_secret_credential_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_secret_credential_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_secret_credential_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_secret_credential_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_secret_credential_ceremony_transactions_id_seq OWNED BY public.client_secret_credential_ceremony_transactions.id;


--
-- Name: client_sign_in_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_in_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: client_sign_in_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_in_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_in_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_in_flow_statuses_id_seq OWNED BY public.client_sign_in_flow_statuses.id;


--
-- Name: client_sign_in_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_in_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    selected_region_id bigint,
    selected_persona_id bigint,
    selector_completed_at timestamp(6) with time zone,
    session_issued_at timestamp(6) with time zone,
    CONSTRAINT chk_app_sign_in_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_app_sign_in_sequence_tickets_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: client_sign_in_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_in_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_in_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_in_flows_id_seq OWNED BY public.client_sign_in_flows.id;


--
-- Name: client_sign_out_flow_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_out_flow_kinds (
    id bigint NOT NULL
);


--
-- Name: client_sign_out_flow_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_out_flow_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_out_flow_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_out_flow_kinds_id_seq OWNED BY public.client_sign_out_flow_kinds.id;


--
-- Name: client_sign_out_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_out_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: client_sign_out_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_out_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_out_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_out_flow_statuses_id_seq OWNED BY public.client_sign_out_flow_statuses.id;


--
-- Name: client_sign_out_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_out_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    status_id bigint DEFAULT 10 NOT NULL,
    kind_id bigint DEFAULT 0 NOT NULL,
    refresh_token_family_id character varying,
    requested_at timestamp(6) with time zone NOT NULL,
    access_discarded_at timestamp(6) with time zone,
    logically_revoked_at timestamp(6) with time zone,
    access_expires_at timestamp(6) with time zone NOT NULL,
    refresh_expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    failed_at timestamp(6) with time zone,
    return_to text,
    nonce_digest character varying,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT chk_client_sign_out_cycles_retention_order CHECK ((discarded_at <= purged_at)),
    CONSTRAINT chk_client_sign_out_cycles_token_expiry_order CHECK ((access_expires_at <= refresh_expires_at))
);


--
-- Name: client_sign_out_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_out_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_out_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_out_flows_id_seq OWNED BY public.client_sign_out_flows.id;


--
-- Name: client_sign_up_flow_cleanup_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_up_flow_cleanup_statuses (
    id bigint NOT NULL
);


--
-- Name: client_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_up_flow_cleanup_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_up_flow_cleanup_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_up_flow_cleanup_statuses_id_seq OWNED BY public.client_sign_up_flow_cleanup_statuses.id;


--
-- Name: client_sign_up_flow_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_up_flow_statuses (
    id bigint NOT NULL
);


--
-- Name: client_sign_up_flow_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_up_flow_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_up_flow_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_up_flow_statuses_id_seq OWNED BY public.client_sign_up_flow_statuses.id;


--
-- Name: client_sign_up_flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_sign_up_flows (
    id bigint NOT NULL,
    public_id character varying(21) NOT NULL,
    principal_id bigint,
    token_id bigint,
    state character varying NOT NULL,
    step character varying NOT NULL,
    return_to text,
    nonce_digest character varying NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    completed_at timestamp(6) with time zone,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    status_id bigint DEFAULT 10 NOT NULL,
    entry_method character varying NOT NULL,
    pending_contact_type character varying,
    pending_contact_id bigint,
    social_provider character varying,
    completed_requirements jsonb DEFAULT '{}'::jsonb NOT NULL,
    failed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    checkpoint_version integer DEFAULT 0 NOT NULL,
    cleanup_attempted_at timestamp(6) with time zone,
    cleanup_completed_at timestamp(6) with time zone,
    cleanup_error_code character varying,
    pending_passkey_registration_id bigint,
    cleanup_attempts_count integer DEFAULT 0 NOT NULL,
    cleanup_status_id bigint DEFAULT 10 NOT NULL,
    CONSTRAINT chk_app_sign_up_sequence_tickets_lifetime_order CHECK ((issued_at < expires_at)),
    CONSTRAINT chk_app_sign_up_sequence_tickets_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: client_sign_up_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_sign_up_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_sign_up_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_sign_up_flows_id_seq OWNED BY public.client_sign_up_flows.id;


--
-- Name: client_social_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_social_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    provider character varying NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    provider_subject_ref character varying,
    provider_subject_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_social_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_social_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_social_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_social_ceremony_transactions_id_seq OWNED BY public.client_social_ceremony_transactions.id;


--
-- Name: client_step_up_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_step_up_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    required_scope character varying NOT NULL,
    required_aal character varying NOT NULL,
    allowed_methods text NOT NULL,
    resource_ref character varying,
    return_to character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    method character varying,
    aal character varying,
    verified_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_step_up_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_step_up_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_step_up_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_step_up_ceremony_transactions_id_seq OWNED BY public.client_step_up_ceremony_transactions.id;


--
-- Name: client_step_up_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_step_up_sessions (
    id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    method character varying,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    return_to text NOT NULL,
    scope character varying NOT NULL,
    status character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_token_id bigint NOT NULL,
    verified_at timestamp(6) with time zone
);


--
-- Name: client_step_up_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_step_up_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_step_up_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_step_up_sessions_id_seq OWNED BY public.client_step_up_sessions.id;


--
-- Name: client_telephone_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_telephone_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    telephone_candidate_ref character varying,
    normalized_number_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_telephone_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_telephone_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_telephone_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_telephone_ceremony_transactions_id_seq OWNED BY public.client_telephone_ceremony_transactions.id;


--
-- Name: client_token_binding_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_binding_methods (
    id bigint NOT NULL
);


--
-- Name: client_token_binding_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_binding_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_binding_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_binding_methods_id_seq OWNED BY public.client_token_binding_methods.id;


--
-- Name: client_token_dbsc_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_dbsc_statuses (
    id bigint NOT NULL
);


--
-- Name: client_token_dbsc_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_dbsc_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_dbsc_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_dbsc_statuses_id_seq OWNED BY public.client_token_dbsc_statuses.id;


--
-- Name: client_token_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_kinds (
    id bigint NOT NULL
);


--
-- Name: client_token_kinds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_kinds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_kinds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_kinds_id_seq OWNED BY public.client_token_kinds.id;


--
-- Name: client_token_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_token_statuses (
    id bigint NOT NULL
);


--
-- Name: client_token_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_token_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_token_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_token_statuses_id_seq OWNED BY public.client_token_statuses.id;


--
-- Name: client_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_tokens (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    dbsc_challenge text,
    dbsc_challenge_issued_at timestamp(6) with time zone,
    dbsc_public_key jsonb,
    dbsc_session_id character varying,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    last_step_up_at timestamp(6) with time zone,
    last_step_up_scope character varying,
    last_used_at timestamp(6) with time zone,
    public_id character varying(21) DEFAULT ''::character varying NOT NULL,
    refresh_token_digest bytea,
    refresh_token_family_id character varying,
    refresh_token_generation integer DEFAULT 0 NOT NULL,
    rotated_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone NOT NULL,
    user_id bigint NOT NULL,
    user_token_binding_method_id bigint DEFAULT 0 NOT NULL,
    user_token_dbsc_status_id bigint DEFAULT 0 NOT NULL,
    user_token_kind_id bigint DEFAULT 11 NOT NULL,
    user_token_status_id bigint DEFAULT 1 NOT NULL,
    dpop_jkt character varying,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    oidc_connection_id bigint,
    oidc_client_id character varying(64),
    oidc_scope character varying,
    oidc_sid uuid DEFAULT gen_random_uuid(),
    oidc_jti uuid DEFAULT gen_random_uuid(),
    device_session_id bigint,
    last_step_up_aal character varying,
    last_step_up_method character varying,
    last_step_up_purpose character varying,
    last_step_up_audience character varying,
    last_step_up_session_public_id character varying,
    selected_account_public_id character varying,
    selected_collective_public_id character varying,
    selected_collective_unit_public_id character varying,
    selected_avatar_public_id character varying,
    selected_at timestamp(6) with time zone,
    CONSTRAINT chk_user_tokens_kind_id_positive CHECK ((user_token_kind_id >= 0)),
    CONSTRAINT chk_user_tokens_status_id_positive CHECK ((user_token_status_id >= 0))
);


--
-- Name: client_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_tokens_id_seq OWNED BY public.client_tokens.id;


--
-- Name: client_totp_ceremony_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_totp_ceremony_transactions (
    id bigint NOT NULL,
    transaction_id character varying NOT NULL,
    surface character varying NOT NULL,
    actor_ref character varying NOT NULL,
    session_ref character varying NOT NULL,
    operation character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    grant_jti character varying NOT NULL,
    result_jti character varying,
    credential_candidate_ref character varying,
    credential_candidate_digest character varying,
    expires_at timestamp(6) with time zone NOT NULL,
    consumed_at timestamp(6) with time zone,
    lock_version bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: client_totp_ceremony_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_totp_ceremony_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_totp_ceremony_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_totp_ceremony_transactions_id_seq OWNED BY public.client_totp_ceremony_transactions.id;


--
-- Name: client_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_verifications (
    id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    last_used_at timestamp(6) with time zone,
    token_digest character varying NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    user_token_id bigint NOT NULL,
    discarded_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    purged_at timestamp(6) with time zone DEFAULT 'infinity'::timestamp with time zone NOT NULL,
    CONSTRAINT chk_user_verifications_retention_order CHECK ((discarded_at <= purged_at))
);


--
-- Name: client_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_verifications_id_seq OWNED BY public.client_verifications.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: user_verifications_user_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_verifications_user_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_verifications_user_token_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_verifications_user_token_id_seq OWNED BY public.client_verifications.user_token_id;


--
-- Name: client_authorization_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_authorization_codes ALTER COLUMN id SET DEFAULT nextval('public.client_authorization_codes_id_seq'::regclass);


--
-- Name: client_device_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_device_sessions ALTER COLUMN id SET DEFAULT nextval('public.client_device_sessions_id_seq'::regclass);


--
-- Name: client_dpop_proof_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_dpop_proof_states ALTER COLUMN id SET DEFAULT nextval('public.client_dpop_proof_states_id_seq'::regclass);


--
-- Name: client_email_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_email_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_oauth_callback_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oauth_callback_states ALTER COLUMN id SET DEFAULT nextval('public.client_oauth_callback_states_id_seq'::regclass);


--
-- Name: client_oidc_authorization_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_authorization_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_oidc_authorization_transactions_id_seq'::regclass);


--
-- Name: client_oidc_connections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_connections ALTER COLUMN id SET DEFAULT nextval('public.client_oidc_connections_id_seq'::regclass);


--
-- Name: client_passkey_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_passkey_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_secret_credential_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_secret_credential_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_sign_in_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_in_flow_statuses_id_seq'::regclass);


--
-- Name: client_sign_in_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows ALTER COLUMN id SET DEFAULT nextval('public.client_sign_in_flows_id_seq'::regclass);


--
-- Name: client_sign_out_flow_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_kinds ALTER COLUMN id SET DEFAULT nextval('public.client_sign_out_flow_kinds_id_seq'::regclass);


--
-- Name: client_sign_out_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_out_flow_statuses_id_seq'::regclass);


--
-- Name: client_sign_out_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows ALTER COLUMN id SET DEFAULT nextval('public.client_sign_out_flows_id_seq'::regclass);


--
-- Name: client_sign_up_flow_cleanup_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_cleanup_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_up_flow_cleanup_statuses_id_seq'::regclass);


--
-- Name: client_sign_up_flow_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_sign_up_flow_statuses_id_seq'::regclass);


--
-- Name: client_sign_up_flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows ALTER COLUMN id SET DEFAULT nextval('public.client_sign_up_flows_id_seq'::regclass);


--
-- Name: client_social_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_social_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_social_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_step_up_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_step_up_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_step_up_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions ALTER COLUMN id SET DEFAULT nextval('public.client_step_up_sessions_id_seq'::regclass);


--
-- Name: client_telephone_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_telephone_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_token_binding_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_binding_methods ALTER COLUMN id SET DEFAULT nextval('public.client_token_binding_methods_id_seq'::regclass);


--
-- Name: client_token_dbsc_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_dbsc_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_token_dbsc_statuses_id_seq'::regclass);


--
-- Name: client_token_kinds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_kinds ALTER COLUMN id SET DEFAULT nextval('public.client_token_kinds_id_seq'::regclass);


--
-- Name: client_token_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_statuses ALTER COLUMN id SET DEFAULT nextval('public.client_token_statuses_id_seq'::regclass);


--
-- Name: client_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens ALTER COLUMN id SET DEFAULT nextval('public.client_tokens_id_seq'::regclass);


--
-- Name: client_totp_ceremony_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_ceremony_transactions ALTER COLUMN id SET DEFAULT nextval('public.client_totp_ceremony_transactions_id_seq'::regclass);


--
-- Name: client_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_verifications ALTER COLUMN id SET DEFAULT nextval('public.client_verifications_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: client_sign_in_flows chk_client_sign_in_cycles_status_state; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_sign_in_flows
    ADD CONSTRAINT chk_client_sign_in_cycles_status_state CHECK (((state)::text =
CASE status_id
    WHEN 10 THEN 'PRIMARY_PENDING'::text
    WHEN 20 THEN 'MFA_PENDING'::text
    WHEN 30 THEN 'SESSION_LIMIT_PENDING'::text
    WHEN 40 THEN 'GUARDRAIL_PENDING'::text
    WHEN 50 THEN 'SESSION_ISSUANCE_PENDING'::text
    WHEN 60 THEN 'CHECKPOINT_PENDING'::text
    WHEN 65 THEN 'SELECTOR_PENDING'::text
    WHEN 70 THEN 'DASHBOARD_PENDING'::text
    WHEN 80 THEN 'RETURN_PENDING'::text
    WHEN 100 THEN 'COMPLETED'::text
    WHEN 900 THEN 'FAILED'::text
    ELSE NULL::text
END)) NOT VALID;


--
-- Name: client_sign_in_flows chk_client_sign_in_cycles_status_step; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_sign_in_flows
    ADD CONSTRAINT chk_client_sign_in_cycles_status_step CHECK (((step)::text =
CASE status_id
    WHEN 10 THEN 'primary'::text
    WHEN 20 THEN 'mfa'::text
    WHEN 30 THEN 'session_limit'::text
    WHEN 40 THEN 'guardrail'::text
    WHEN 50 THEN 'session_issuance'::text
    WHEN 60 THEN 'checkpoint'::text
    WHEN 65 THEN 'selector'::text
    WHEN 70 THEN 'dashboard'::text
    WHEN 80 THEN 'return_to'::text
    WHEN 100 THEN 'completed'::text
    WHEN 900 THEN 'failed'::text
    ELSE NULL::text
END)) NOT VALID;


--
-- Name: client_step_up_sessions chk_user_step_up_sessions_retention_order; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.client_step_up_sessions
    ADD CONSTRAINT chk_user_step_up_sessions_retention_order CHECK ((discarded_at <= purged_at)) NOT VALID;


--
-- Name: client_authorization_codes client_authorization_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_authorization_codes
    ADD CONSTRAINT client_authorization_codes_pkey PRIMARY KEY (id);


--
-- Name: client_device_sessions client_device_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_device_sessions
    ADD CONSTRAINT client_device_sessions_pkey PRIMARY KEY (id);


--
-- Name: client_dpop_proof_states client_dpop_proof_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_dpop_proof_states
    ADD CONSTRAINT client_dpop_proof_states_pkey PRIMARY KEY (id);


--
-- Name: client_email_ceremony_transactions client_email_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_email_ceremony_transactions
    ADD CONSTRAINT client_email_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_oauth_callback_states client_oauth_callback_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oauth_callback_states
    ADD CONSTRAINT client_oauth_callback_states_pkey PRIMARY KEY (id);


--
-- Name: client_oidc_authorization_transactions client_oidc_authorization_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_authorization_transactions
    ADD CONSTRAINT client_oidc_authorization_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_oidc_connections client_oidc_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_oidc_connections
    ADD CONSTRAINT client_oidc_connections_pkey PRIMARY KEY (id);


--
-- Name: client_passkey_ceremony_transactions client_passkey_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_passkey_ceremony_transactions
    ADD CONSTRAINT client_passkey_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_secret_credential_ceremony_transactions client_secret_credential_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_secret_credential_ceremony_transactions
    ADD CONSTRAINT client_secret_credential_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_sign_in_flow_statuses client_sign_in_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flow_statuses
    ADD CONSTRAINT client_sign_in_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_in_flows client_sign_in_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT client_sign_in_flows_pkey PRIMARY KEY (id);


--
-- Name: client_sign_out_flow_kinds client_sign_out_flow_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_kinds
    ADD CONSTRAINT client_sign_out_flow_kinds_pkey PRIMARY KEY (id);


--
-- Name: client_sign_out_flow_statuses client_sign_out_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flow_statuses
    ADD CONSTRAINT client_sign_out_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_out_flows client_sign_out_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT client_sign_out_flows_pkey PRIMARY KEY (id);


--
-- Name: client_sign_up_flow_cleanup_statuses client_sign_up_flow_cleanup_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_cleanup_statuses
    ADD CONSTRAINT client_sign_up_flow_cleanup_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_up_flow_statuses client_sign_up_flow_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flow_statuses
    ADD CONSTRAINT client_sign_up_flow_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_sign_up_flows client_sign_up_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT client_sign_up_flows_pkey PRIMARY KEY (id);


--
-- Name: client_social_ceremony_transactions client_social_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_social_ceremony_transactions
    ADD CONSTRAINT client_social_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_step_up_ceremony_transactions client_step_up_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_ceremony_transactions
    ADD CONSTRAINT client_step_up_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_step_up_sessions client_step_up_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT client_step_up_sessions_pkey PRIMARY KEY (id);


--
-- Name: client_telephone_ceremony_transactions client_telephone_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_telephone_ceremony_transactions
    ADD CONSTRAINT client_telephone_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_token_binding_methods client_token_binding_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_binding_methods
    ADD CONSTRAINT client_token_binding_methods_pkey PRIMARY KEY (id);


--
-- Name: client_token_dbsc_statuses client_token_dbsc_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_dbsc_statuses
    ADD CONSTRAINT client_token_dbsc_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_token_kinds client_token_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_kinds
    ADD CONSTRAINT client_token_kinds_pkey PRIMARY KEY (id);


--
-- Name: client_token_statuses client_token_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_token_statuses
    ADD CONSTRAINT client_token_statuses_pkey PRIMARY KEY (id);


--
-- Name: client_tokens client_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT client_tokens_pkey PRIMARY KEY (id);


--
-- Name: client_totp_ceremony_transactions client_totp_ceremony_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_totp_ceremony_transactions
    ADD CONSTRAINT client_totp_ceremony_transactions_pkey PRIMARY KEY (id);


--
-- Name: client_verifications client_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_verifications
    ADD CONSTRAINT client_verifications_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_on_actor_ref_session_ref_1470aaddcc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_1470aaddcc ON public.client_secret_credential_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_334fbe1b51; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_334fbe1b51 ON public.client_passkey_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_4f24c7001d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_4f24c7001d ON public.client_step_up_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_7d958a782d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_7d958a782d ON public.client_email_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_b5b014c24f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_b5b014c24f ON public.client_social_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_e19ee6ad85; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_e19ee6ad85 ON public.client_telephone_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_actor_ref_session_ref_e256c5d4a6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_actor_ref_session_ref_e256c5d4a6 ON public.client_totp_ceremony_transactions USING btree (actor_ref, session_ref);


--
-- Name: idx_on_client_id_login_challenge_8f71e56454; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_client_id_login_challenge_8f71e56454 ON public.client_oidc_authorization_transactions USING btree (client_id, login_challenge);


--
-- Name: idx_on_expires_at_6a705a7bb7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_expires_at_6a705a7bb7 ON public.client_secret_credential_ceremony_transactions USING btree (expires_at);


--
-- Name: idx_on_grant_jti_58e101b1d8; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_grant_jti_58e101b1d8 ON public.client_secret_credential_ceremony_transactions USING btree (grant_jti);


--
-- Name: idx_on_login_challenge_91d464d261; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_login_challenge_91d464d261 ON public.client_oidc_authorization_transactions USING btree (login_challenge);


--
-- Name: idx_on_provider_provider_subject_digest_8b462593cd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_provider_provider_subject_digest_8b462593cd ON public.client_social_ceremony_transactions USING btree (provider, provider_subject_digest);


--
-- Name: idx_on_result_jti_b20b4e2f25; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_result_jti_b20b4e2f25 ON public.client_secret_credential_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: idx_on_transaction_id_b63311dbbc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_transaction_id_b63311dbbc ON public.client_secret_credential_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_authorization_codes_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_authorization_codes_on_code ON public.client_authorization_codes USING btree (code);


--
-- Name: index_client_authorization_codes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_authorization_codes_on_user_id ON public.client_authorization_codes USING btree (user_id);


--
-- Name: index_client_device_sessions_on_current_refresh_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_current_refresh_token_id ON public.client_device_sessions USING btree (current_refresh_token_id);


--
-- Name: index_client_device_sessions_on_dbsc_session_id_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_dbsc_session_id_digest ON public.client_device_sessions USING btree (dbsc_session_id_digest);


--
-- Name: index_client_device_sessions_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_device_sessions_on_public_id ON public.client_device_sessions USING btree (public_id);


--
-- Name: index_client_device_sessions_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_refresh_token_family_id ON public.client_device_sessions USING btree (refresh_token_family_id);


--
-- Name: index_client_device_sessions_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_revoked_at ON public.client_device_sessions USING btree (revoked_at);


--
-- Name: index_client_device_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_device_sessions_on_user_id ON public.client_device_sessions USING btree (user_id);


--
-- Name: index_client_dpop_proof_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_dpop_proof_states_on_expires_at ON public.client_dpop_proof_states USING btree (expires_at);


--
-- Name: index_client_dpop_proof_states_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_dpop_proof_states_on_jti ON public.client_dpop_proof_states USING btree (jti) WHERE (jti IS NOT NULL);


--
-- Name: index_client_dpop_proof_states_on_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_dpop_proof_states_on_nonce ON public.client_dpop_proof_states USING btree (nonce) WHERE (nonce IS NOT NULL);


--
-- Name: index_client_email_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_email_ceremony_transactions_on_expires_at ON public.client_email_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_email_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_grant_jti ON public.client_email_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_email_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_result_jti ON public.client_email_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_email_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_email_ceremony_transactions_on_transaction_id ON public.client_email_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_oauth_callback_states_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_oauth_callback_states_on_expires_at ON public.client_oauth_callback_states USING btree (expires_at);


--
-- Name: index_client_oauth_callback_states_on_state_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oauth_callback_states_on_state_digest ON public.client_oauth_callback_states USING btree (state_digest);


--
-- Name: index_client_oidc_authorization_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oidc_authorization_transactions_on_transaction_id ON public.client_oidc_authorization_transactions USING btree (transaction_id);


--
-- Name: index_client_oidc_connections_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oidc_connections_on_public_id ON public.client_oidc_connections USING btree (public_id);


--
-- Name: index_client_oidc_connections_on_user_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_oidc_connections_on_user_id_and_client_id ON public.client_oidc_connections USING btree (user_id, client_id);


--
-- Name: index_client_passkey_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_passkey_ceremony_transactions_on_expires_at ON public.client_passkey_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_passkey_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_ceremony_transactions_on_grant_jti ON public.client_passkey_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_passkey_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_ceremony_transactions_on_result_jti ON public.client_passkey_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_passkey_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_passkey_ceremony_transactions_on_transaction_id ON public.client_passkey_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_sign_in_flows_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_discarded_at ON public.client_sign_in_flows USING btree (discarded_at);


--
-- Name: index_client_sign_in_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_expires_at ON public.client_sign_in_flows USING btree (expires_at);


--
-- Name: index_client_sign_in_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_principal_id ON public.client_sign_in_flows USING btree (principal_id);


--
-- Name: index_client_sign_in_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_in_flows_on_public_id ON public.client_sign_in_flows USING btree (public_id);


--
-- Name: index_client_sign_in_flows_on_selected_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_selected_persona_id ON public.client_sign_in_flows USING btree (selected_persona_id);


--
-- Name: index_client_sign_in_flows_on_selected_region_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_selected_region_id ON public.client_sign_in_flows USING btree (selected_region_id);


--
-- Name: index_client_sign_in_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_state ON public.client_sign_in_flows USING btree (state);


--
-- Name: index_client_sign_in_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_status_id ON public.client_sign_in_flows USING btree (status_id);


--
-- Name: index_client_sign_in_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_in_flows_on_token_id ON public.client_sign_in_flows USING btree (token_id);


--
-- Name: index_client_sign_out_flows_on_access_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_access_expires_at ON public.client_sign_out_flows USING btree (access_expires_at);


--
-- Name: index_client_sign_out_flows_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_discarded_at ON public.client_sign_out_flows USING btree (discarded_at);


--
-- Name: index_client_sign_out_flows_on_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_kind_id ON public.client_sign_out_flows USING btree (kind_id);


--
-- Name: index_client_sign_out_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_principal_id ON public.client_sign_out_flows USING btree (principal_id);


--
-- Name: index_client_sign_out_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_out_flows_on_public_id ON public.client_sign_out_flows USING btree (public_id);


--
-- Name: index_client_sign_out_flows_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_purged_at ON public.client_sign_out_flows USING btree (purged_at);


--
-- Name: index_client_sign_out_flows_on_refresh_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_refresh_expires_at ON public.client_sign_out_flows USING btree (refresh_expires_at);


--
-- Name: index_client_sign_out_flows_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_refresh_token_family_id ON public.client_sign_out_flows USING btree (refresh_token_family_id);


--
-- Name: index_client_sign_out_flows_on_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_status_id ON public.client_sign_out_flows USING btree (status_id);


--
-- Name: index_client_sign_out_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_out_flows_on_token_id ON public.client_sign_out_flows USING btree (token_id);


--
-- Name: index_client_sign_up_flows_on_cleanup_status_id_and_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_cleanup_status_id_and_purged_at ON public.client_sign_up_flows USING btree (cleanup_status_id, purged_at);


--
-- Name: index_client_sign_up_flows_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_discarded_at ON public.client_sign_up_flows USING btree (discarded_at);


--
-- Name: index_client_sign_up_flows_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_expires_at ON public.client_sign_up_flows USING btree (expires_at);


--
-- Name: index_client_sign_up_flows_on_pending_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_pending_contact_id ON public.client_sign_up_flows USING btree (pending_contact_id);


--
-- Name: index_client_sign_up_flows_on_pending_passkey_registration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_pending_passkey_registration_id ON public.client_sign_up_flows USING btree (pending_passkey_registration_id);


--
-- Name: index_client_sign_up_flows_on_principal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_principal_id ON public.client_sign_up_flows USING btree (principal_id);


--
-- Name: index_client_sign_up_flows_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_sign_up_flows_on_public_id ON public.client_sign_up_flows USING btree (public_id);


--
-- Name: index_client_sign_up_flows_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_state ON public.client_sign_up_flows USING btree (state);


--
-- Name: index_client_sign_up_flows_on_status_id_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_status_id_and_expires_at ON public.client_sign_up_flows USING btree (status_id, expires_at);


--
-- Name: index_client_sign_up_flows_on_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_sign_up_flows_on_token_id ON public.client_sign_up_flows USING btree (token_id);


--
-- Name: index_client_social_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_social_ceremony_transactions_on_expires_at ON public.client_social_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_social_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_ceremony_transactions_on_grant_jti ON public.client_social_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_social_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_ceremony_transactions_on_result_jti ON public.client_social_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_social_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_social_ceremony_transactions_on_transaction_id ON public.client_social_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_step_up_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_step_up_ceremony_transactions_on_expires_at ON public.client_step_up_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_step_up_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_grant_jti ON public.client_step_up_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_step_up_ceremony_transactions_on_required_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_step_up_ceremony_transactions_on_required_scope ON public.client_step_up_ceremony_transactions USING btree (required_scope);


--
-- Name: index_client_step_up_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_result_jti ON public.client_step_up_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_step_up_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_ceremony_transactions_on_transaction_id ON public.client_step_up_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_step_up_sessions_on_user_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_step_up_sessions_on_user_token_id ON public.client_step_up_sessions USING btree (user_token_id);


--
-- Name: index_client_telephone_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_telephone_ceremony_transactions_on_expires_at ON public.client_telephone_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_telephone_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephone_ceremony_transactions_on_grant_jti ON public.client_telephone_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_telephone_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephone_ceremony_transactions_on_result_jti ON public.client_telephone_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_telephone_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_telephone_ceremony_transactions_on_transaction_id ON public.client_telephone_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_tokens_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_created_at ON public.client_tokens USING btree (created_at);


--
-- Name: index_client_tokens_on_dbsc_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_dbsc_session_id ON public.client_tokens USING btree (dbsc_session_id);


--
-- Name: index_client_tokens_on_device_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_device_session_id ON public.client_tokens USING btree (device_session_id);


--
-- Name: index_client_tokens_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_discarded_at ON public.client_tokens USING btree (discarded_at);


--
-- Name: index_client_tokens_on_oidc_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_oidc_connection_id ON public.client_tokens USING btree (oidc_connection_id);


--
-- Name: index_client_tokens_on_oidc_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_oidc_jti ON public.client_tokens USING btree (oidc_jti);


--
-- Name: index_client_tokens_on_oidc_sid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_oidc_sid ON public.client_tokens USING btree (oidc_sid);


--
-- Name: index_client_tokens_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_public_id ON public.client_tokens USING btree (public_id);


--
-- Name: index_client_tokens_on_purged_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_purged_at ON public.client_tokens USING btree (purged_at);


--
-- Name: index_client_tokens_on_refresh_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_tokens_on_refresh_token_digest ON public.client_tokens USING btree (refresh_token_digest);


--
-- Name: index_client_tokens_on_refresh_token_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_refresh_token_family_id ON public.client_tokens USING btree (refresh_token_family_id);


--
-- Name: index_client_tokens_on_rotated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_rotated_at ON public.client_tokens USING btree (rotated_at);


--
-- Name: index_client_tokens_on_selected_account_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_selected_account_public_id ON public.client_tokens USING btree (selected_account_public_id);


--
-- Name: index_client_tokens_on_selected_avatar_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_selected_avatar_public_id ON public.client_tokens USING btree (selected_avatar_public_id);


--
-- Name: index_client_tokens_on_selected_collective_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_selected_collective_public_id ON public.client_tokens USING btree (selected_collective_public_id);


--
-- Name: index_client_tokens_on_user_id_and_last_step_up_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_id_and_last_step_up_at ON public.client_tokens USING btree (user_id, last_step_up_at);


--
-- Name: index_client_tokens_on_user_id_and_oidc_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_id_and_oidc_client_id ON public.client_tokens USING btree (user_id, oidc_client_id);


--
-- Name: index_client_tokens_on_user_token_binding_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_binding_method_id ON public.client_tokens USING btree (user_token_binding_method_id);


--
-- Name: index_client_tokens_on_user_token_dbsc_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_dbsc_status_id ON public.client_tokens USING btree (user_token_dbsc_status_id);


--
-- Name: index_client_tokens_on_user_token_kind_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_kind_id ON public.client_tokens USING btree (user_token_kind_id);


--
-- Name: index_client_tokens_on_user_token_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_tokens_on_user_token_status_id ON public.client_tokens USING btree (user_token_status_id);


--
-- Name: index_client_totp_ceremony_transactions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_totp_ceremony_transactions_on_expires_at ON public.client_totp_ceremony_transactions USING btree (expires_at);


--
-- Name: index_client_totp_ceremony_transactions_on_grant_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_ceremony_transactions_on_grant_jti ON public.client_totp_ceremony_transactions USING btree (grant_jti);


--
-- Name: index_client_totp_ceremony_transactions_on_result_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_ceremony_transactions_on_result_jti ON public.client_totp_ceremony_transactions USING btree (result_jti) WHERE (result_jti IS NOT NULL);


--
-- Name: index_client_totp_ceremony_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_totp_ceremony_transactions_on_transaction_id ON public.client_totp_ceremony_transactions USING btree (transaction_id);


--
-- Name: index_client_verifications_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_verifications_on_token_digest ON public.client_verifications USING btree (token_digest);


--
-- Name: index_client_verifications_on_user_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_verifications_on_user_token_id ON public.client_verifications USING btree (user_token_id);


--
-- Name: client_verifications fk_rails_18a774c144; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_verifications
    ADD CONSTRAINT fk_rails_18a774c144 FOREIGN KEY (user_token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_sign_out_flows fk_rails_39d731f429; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_39d731f429 FOREIGN KEY (kind_id) REFERENCES public.client_sign_out_flow_kinds(id) NOT VALID;


--
-- Name: client_sign_out_flows fk_rails_4bbbc632e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_4bbbc632e2 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_sign_in_flows fk_rails_4e35f66d42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT fk_rails_4e35f66d42 FOREIGN KEY (status_id) REFERENCES public.client_sign_in_flow_statuses(id) NOT VALID;


--
-- Name: client_sign_up_flows fk_rails_533362926d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_533362926d FOREIGN KEY (status_id) REFERENCES public.client_sign_up_flow_statuses(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: client_step_up_sessions fk_rails_64ec203fd3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_step_up_sessions
    ADD CONSTRAINT fk_rails_64ec203fd3 FOREIGN KEY (user_token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_sign_up_flows fk_rails_7b193122e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_7b193122e7 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_sign_up_flows fk_rails_9b0b63a0c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_up_flows
    ADD CONSTRAINT fk_rails_9b0b63a0c6 FOREIGN KEY (cleanup_status_id) REFERENCES public.client_sign_up_flow_cleanup_statuses(id) NOT VALID;


--
-- Name: client_sign_out_flows fk_rails_bbc7001388; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_out_flows
    ADD CONSTRAINT fk_rails_bbc7001388 FOREIGN KEY (status_id) REFERENCES public.client_sign_out_flow_statuses(id) NOT VALID;


--
-- Name: client_sign_in_flows fk_rails_bd772deef1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_sign_in_flows
    ADD CONSTRAINT fk_rails_bd772deef1 FOREIGN KEY (token_id) REFERENCES public.client_tokens(id) ON DELETE CASCADE NOT VALID;


--
-- Name: client_tokens fk_rails_c11b41180d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_rails_c11b41180d FOREIGN KEY (user_token_status_id) REFERENCES public.client_token_statuses(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: client_tokens fk_rails_f69bf5b8f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_rails_f69bf5b8f0 FOREIGN KEY (user_token_kind_id) REFERENCES public.client_token_kinds(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: client_tokens fk_user_tokens_on_user_token_binding_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_user_tokens_on_user_token_binding_method_id FOREIGN KEY (user_token_binding_method_id) REFERENCES public.client_token_binding_methods(id) NOT VALID;


--
-- Name: client_tokens fk_user_tokens_on_user_token_dbsc_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_tokens
    ADD CONSTRAINT fk_user_tokens_on_user_token_dbsc_status_id FOREIGN KEY (user_token_dbsc_status_id) REFERENCES public.client_token_dbsc_statuses(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260616150020'),
('20260616150010'),
('20260616150005'),
('20260616150000'),
('20260612000001'),
('20260611150000'),
('20260611100000'),
('20260606120000'),
('20260603140000'),
('20260603130000'),
('20260603124000'),
('20260603123000'),
('20260603122000'),
('20260603121000'),
('20260603120000'),
('20260530130100'),
('20260530130000'),
('20260528183000'),
('20260528162100'),
('20260526120100'),
('20260526120000'),
('20260525233000'),
('20260525210000'),
('20260525200500'),
('20260525200000'),
('20260525131500'),
('20260525124500'),
('20260525123000'),
('20260520190000'),
('20260520143011'),
('20260520143002'),
('20260520130000'),
('20260519111000'),
('20260519110000'),
('20260519092000'),
('20260519091000'),
('20260519090000'),
('20260518085548'),
('20260518084934'),
('20260518044313'),
('20260518020000'),
('20260517120000'),
('20260508202600'),
('20260508160000'),
('20260508151000'),
('20260508140999'),
('20260508135006'),
('20260507010001'),
('20260501000000');

