# typed: false
# frozen_string_literal: true

module Auth
  class CurrentResourceResolver
    Result =
      Struct.new(
        :resource,
        :session_public_id,
        :payload,
        :failure_reason,
        keyword_init: true,
      ) do
        def success?
          resource.present?
        end
      end

    def initialize(access_token:, request_host:, resource_type:, resource_class:, token_class:, test_env:,
                   authorization_scheme: nil, dpop_proof: nil, request_method: nil, request_uri: nil)
      @access_token = access_token
      @request_host = request_host
      @resource_type = resource_type
      @resource_class = resource_class
      @token_class = token_class
      @test_env = test_env
      @authorization_scheme = authorization_scheme
      @dpop_proof = dpop_proof
      @request_method = request_method
      @request_uri = request_uri
    end

    def call
      return failure(:blank_access_token) if @access_token.blank?

      payload = Authentication::Base::Token.decode(@access_token, host: @request_host, resource_type: @resource_type)
      if payload.blank?
        sid = Authentication::Base::Token.extract_session_id_allow_expired(
          @access_token,
          host: @request_host,
          resource_type: @resource_type,
        )
        return failure(:token_decode_failed, session_public_id: sid) if sid.present?

        return failure(:token_decode_failed)
      end
      return failure(:dpop_verification_failed, payload: payload) unless dpop_valid?(payload)

      unless Authentication::Base::Token.validate_actor_claim!(payload, @resource_type)
        return failure(:actor_mismatch, payload: payload)
      end

      sid = Authentication::Base::Token.extract_session_id(payload)
      return failure(:missing_session_id, payload: payload) if sid.blank?
      return failure(:token_session_not_found, payload: payload) unless token_exists?(sid)

      resource = @resource_class.find_by(id: Authentication::Base::Token.extract_subject(payload))
      return failure(:resource_not_found, payload: payload, session_public_id: sid) if resource.blank?

      Result.new(resource: resource, session_public_id: sid, payload: payload, failure_reason: nil)
    end

    private

    def dpop_valid?(payload)
      token_jkt = payload.dig("cnf", "jkt")
      scheme = @authorization_scheme.to_s
      scheme_dpop = scheme.casecmp?("DPoP")

      return true if token_jkt.blank? && !scheme_dpop && @dpop_proof.blank?
      return false unless scheme_dpop
      return false if token_jkt.blank?

      result = Dpop::RequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: @dpop_proof,
        request_method: @request_method,
        request_uri: @request_uri,
        access_token: @access_token,
      ).call

      result.valid?
    end

    def token_exists?(session_public_id)
      check_logic =
        lambda do
          usable_tokens =
            if @token_class.respond_to?(:currently_usable_at)
              @token_class.currently_usable_at
            else
              @token_class.where(nil)
            end
          usable_tokens.where(session_id: session_public_id)
            .or(usable_tokens.where(public_id: session_public_id))
            .exists?
        end

      # Use the primary database for revocation-sensitive checks so a recently
      # revoked session cannot slip through replica lag.
      token_connection_owner.connected_to(role: :writing, &check_logic)
    end

    def token_connection_owner
      klass = @token_class
      return TokenRecord unless klass.respond_to?(:connection_class?)

      klass = klass.superclass until klass.connection_class?
      klass
    end

    def failure(reason, payload: nil, session_public_id: nil)
      Result.new(
        resource: nil,
        session_public_id: session_public_id,
        payload: payload,
        failure_reason: reason,
      )
    end
  end
end
