# typed: false
# frozen_string_literal: true

module Oidc
  class TokenExchangeService < ApplicationService
    Result =
      Data.define(:success, :token_response, :error, :error_description) do
        def success? = success
      end

    def initialize(grant_type:, code:, redirect_uri:, client_id:, client_secret:, code_verifier:,
                   dpop_proof: nil, token_endpoint_uri: nil, request_method: "POST")
      super()
      @grant_type = grant_type
      @code = code
      @redirect_uri = redirect_uri
      @client_id = client_id
      @client_secret = client_secret
      @code_verifier = code_verifier
      @dpop_proof = dpop_proof
      @token_endpoint_uri = token_endpoint_uri
      @request_method = request_method
    end

    def call
      validate_grant_type!
      authenticate_client!
      authorization_code = find_and_validate_code!
      verify_pkce!(authorization_code)
      dpop_jkt = validate_dpop_proof!
      consume_and_issue_tokens!(authorization_code, dpop_jkt: dpop_jkt)
    rescue ArgumentError => e
      failure("invalid_request", e.message)
    rescue ActiveRecord::RecordNotFound
      failure("invalid_grant", "Authorization code not found")
    rescue RuntimeError => e
      failure("invalid_grant", e.message)
    end

    private

    attr_reader :grant_type, :code, :redirect_uri, :client_id, :client_secret, :code_verifier,
                :dpop_proof, :token_endpoint_uri, :request_method

    def validate_grant_type!
      raise ArgumentError, "grant_type must be 'authorization_code'" unless grant_type == "authorization_code"
    end

    def authenticate_client!
      return if Oidc::ClientRegistry.authenticate(client_id, client_secret)

      raise ArgumentError, "OIDC client authentication failed"

    end

    def find_and_validate_code!
      authorization_code =
        TokenRecord.connected_to(role: :writing) do
          OperatorAuthorizationCode.lock.find_by(code: code)
        end || SymbolRecord.connected_to(role: :writing) do
          VisitorAuthorizationCode.lock.find_by(code: code)
        end || MarkRecord.connected_to(role: :writing) do
          UserAuthorizationCode.lock.find_by(code: code)
        end

      raise ActiveRecord::RecordNotFound unless authorization_code

      raise RuntimeError, "Authorization code expired" if authorization_code.expired?
      raise RuntimeError, "Authorization code already consumed" if authorization_code.consumed?
      raise RuntimeError, "Authorization code revoked" if authorization_code.revoked?
      raise ArgumentError, "redirect_uri mismatch" unless authorization_code.redirect_uri == redirect_uri
      raise ArgumentError, "client_id mismatch" unless authorization_code.client_id == client_id

      authorization_code
    end

    def verify_pkce!(authorization_code)
      raise ArgumentError, "code_verifier is required" if code_verifier.blank?

      return if authorization_code.verify_pkce(code_verifier)

      raise ArgumentError, "PKCE verification failed"

    end

    def consume_and_issue_tokens!(authorization_code, dpop_jkt: nil)
      client = Oidc::ClientRegistry.find!(client_id)
      resource = authorization_code.resource

      connection_class = connection_class_for(authorization_code)

      connection_class.connected_to(role: :writing) do
        authorization_code.consume!

        token_record = create_token_record!(client, resource, dpop_jkt: dpop_jkt)
        refresh_plain = token_record.rotate_refresh_token!
        now = Time.current
        access_expires_at = now + Authentication::Base::ACCESS_TOKEN_TTL

        id_host =
          if operator_client?(client)
            ENV.fetch("ID_STAFF_URL", "id.org.localhost")
          elsif visitor_client?(client)
            ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          else
            ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
          end

        access_token = Auth::TokenService.encode(
          resource,
          host: id_host,
          session_id: token_record.public_id,
          resource_type: token_resource_type(client),
          expires_at: access_expires_at,
          acr: authorization_code.acr,
          amr: Array(authorization_code.auth_method),
          dpop_jkt: dpop_jkt,
        )

        token_type = dpop_jkt.present? ? "DPoP" : "Bearer"

        Result.new(
          success: true,
          token_response: {
            access_token: access_token,
            token_type: token_type,
            expires_in: Integer(Authentication::Base::ACCESS_TOKEN_TTL.to_s, 10),
            refresh_token: refresh_plain,
          },
          error: nil,
          error_description: nil,
        )
      end
    end

    def create_token_record!(client, resource, dpop_jkt: nil)
      if operator_client?(client)
        OperatorToken.create!(
          staff: resource,
          public_id: SecureRandom.alphanumeric(21),
          lapses_at: Authentication::Base::REFRESH_TOKEN_TTL.from_now,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
          dpop_jkt: dpop_jkt,
        )
      elsif visitor_client?(client)
        VisitorToken.create!(
          visitor: resource,
          public_id: SecureRandom.alphanumeric(21),
          lapses_at: Authentication::Base::REFRESH_TOKEN_TTL.from_now,
          visitor_token_status_id: VisitorTokenStatus::ACTIVE,
          dpop_jkt: dpop_jkt,
        )
      else
        UserToken.create!(
          user: resource,
          public_id: SecureRandom.alphanumeric(21),
          lapses_at: Authentication::Base::REFRESH_TOKEN_TTL.from_now,
          user_token_status_id: UserTokenStatus::ACTIVE,
          dpop_jkt: dpop_jkt,
        )
      end
    end

    def operator_client?(client)
      %w(operator staff).include?(client.resource_type)
    end

    def visitor_client?(client)
      %w(visitor customer).include?(client.resource_type)
    end

    def token_resource_type(client)
      return "operator" if operator_client?(client)
      return "visitor" if visitor_client?(client)

      client.resource_type
    end

    def connection_class_for(authorization_code)
      case authorization_code
      when OperatorAuthorizationCode then TokenRecord
      when VisitorAuthorizationCode then SymbolRecord
      else MarkRecord
      end
    end

    def validate_dpop_proof!
      return nil if dpop_proof.blank?

      result = Dpop::ProofValidator.new(
        proof_jwt: dpop_proof,
        request_method: request_method,
        request_uri: token_endpoint_uri.to_s,
      ).call

      raise ArgumentError, "DPoP proof invalid: #{result.error}" unless result.valid?

      result.jkt
    end

    def failure(error, description)
      Result.new(success: false, token_response: nil, error: error, error_description: description)
    end
  end
end
