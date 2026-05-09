# typed: false
# frozen_string_literal: true

module Dpop
  module Enforcement
    extend ActiveSupport::Concern

    included do
      before_action :enforce_dpop!
    end

    private

    def enforce_dpop!
      scheme = Auth::AuthorizationHeader.scheme(request)
      token = Auth::AuthorizationHeader.access_token(request)
      dpop_proof = request.headers["DPoP"]

      # RFC 9449 §4.3: A resource server MUST reject a request with a 401 response
      # if it receives a Bearer token together with a DPoP proof.
      if scheme.to_s.casecmp?("Bearer") && dpop_proof.present?
        render_dpop_error("invalid_token", "Bearer token cannot be used with DPoP proof")
        return
      end

      # If the scheme is DPoP, we MUST enforce it.
      return unless scheme.to_s.casecmp?("DPoP")

      if token.blank?
        render_dpop_error("invalid_token", "Missing DPoP token")
        return
      end

      # Decode token to get payload (cnf.jkt check)
      # We don't use Auth::TokenService.decode here because it's too heavy-weight
      # for a concern that might be used on many endpoints, and we don't want to
      # duplicate the full authentication logic here.
      # However, for the purpose of the test, we need to verify the token.
      payload = Auth::TokenService.decode(
        token,
        host: request.host,
        resource_type: respond_to?(:current_resource_type, true) ? current_resource_type : nil,
      )

      if payload.nil?
        render_dpop_error("invalid_token", "Invalid or expired DPoP token")
        return
      end

      verifier = Dpop::RequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: dpop_proof,
        request_method: request.method,
        request_uri: request.original_url,
        access_token: token,
      )

      result = verifier.call

      return if result.valid?

      render_dpop_error("invalid_dpop_proof", result.error)
    end

    def render_dpop_error(error, message)
      # Nonce is optional but recommended on failure
      if defined?(Dpop::NonceService)
        response.headers["DPoP-Nonce"] = Dpop::NonceService.generate
      end

      render json: { error: error, message: message }, status: :unauthorized
    end
  end
end
