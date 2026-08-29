# typed: false
# frozen_string_literal: true

# The concrete token controller must declare `OAUTH_RESOURCE_TYPE`. It is read here rather
# than defaulted so that a controller which includes this concern without declaring its
# surface raises immediately instead of silently redeeming another surface's codes.
module BaseOauthTokenEndpoint
  extend ActiveSupport::Concern

  def create
    result = ::OidcTokenExchangeCoordinator.call(
      resource_type: self.class::OAUTH_RESOURCE_TYPE,
      grant_type: params[:grant_type],
      code: params[:code],
      redirect_uri: params[:redirect_uri],
      client_id: params[:client_id],
      client_secret: params[:client_secret],
      client_assertion_type: params[:client_assertion_type],
      client_assertion: params[:client_assertion],
      code_verifier: params[:code_verifier],
      dpop_proof: request.headers["DPoP"],
      token_endpoint_uri: request.original_url,
      request_method: request.request_method,
    )

    if result.success?
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
      render json: result.token_response, status: :ok
    else
      render json: { error: result.error, error_description: result.error_description },
             status: :bad_request
    end
  end
end
