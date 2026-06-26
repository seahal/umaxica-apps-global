# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class TelephonesController < ::Sign::App::ApplicationController
        include CommonRedirect
        include CommonOtp
        include SignTelephoneRegistrable
        include ::SignSettingsAuthorityRedirect

        include ::VerificationClient

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find_by! is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index = redirect_to(acme_app_identity_telephones_path(ri: params[:ri]), status: :see_other)

        def new = redirect_to(new_acme_app_identity_telephones_registration_path(ri: params[:ri]), status: :see_other)

        def edit
          redirect_to(
            edit_acme_app_identity_telephone_path(params.expect(:id), ri: params[:ri]),
            status: :see_other,
          )
        end

        def create = head(:gone)

        def destroy = head(:gone)

        private

        def authorize_telephone_registration! = authorize!(ClientTelephone, to: :create?)

        def verification_required_action? = false
      end
    end
  end
end
