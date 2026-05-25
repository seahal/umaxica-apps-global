# typed: false
# frozen_string_literal: true

module Sign
  module OidcLogout
    extend ActiveSupport::Concern
    include Common::Redirect
    include Sign::OutNotice

    included do
      declare_authentication_mode! :open
    end

    def show
      return invalid_post_logout_redirect_uri if params[:post_logout_redirect_uri].present?

      logout_request = Oidc::LogoutRequest.verify(params[:logout_request])
      return invalid_logout_request unless logout_request

      invalid_client_id =
        params[:client_id].present? &&
        params[:client_id].to_s != logout_request[:client_id]
      return invalid_logout_request if invalid_client_id

      client = Oidc::ClientRegistry.find(logout_request[:client_id])
      return render json: { error: "invalid_request", error_description: "unknown client" },
                    status: :bad_request unless client

      log_out
      issue_sign_out_notice!
      redirect_to(oidc_logout_completed_path(ri: logout_request[:ri]), status: :see_other)
    end

    private

    def invalid_post_logout_redirect_uri
      render json: { error: "invalid_request", error_description: "post_logout_redirect_uri is not supported" },
             status: :bad_request
    end

    def invalid_logout_request
      render json: { error: "invalid_request", error_description: "logout_request is invalid" },
             status: :bad_request
    end
  end
end
