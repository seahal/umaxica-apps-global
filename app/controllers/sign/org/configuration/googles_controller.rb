# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class GooglesController < ApplicationController
        include SocialAuthConcern

        auth_required!

        before_action :authenticate_operator!

        def show
          @google_login_enabled = google_login_enabled?
        end

        def create
          state = prepare_social_auth_intent!("link", provider: "google_org")

          safe_redirect_to(
            omniauth_authorize_path("google_org", state: state),
            fallback: new_sign_org_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        private

        def google_login_enabled?
          current_operator.staff_emails.exists?(
            undeletable: true,
            staff_identity_email_status_id: [OperatorEmailStatus::ACTIVE, OperatorEmailStatus::VERIFIED],
          )
        end
      end
    end
  end
end
