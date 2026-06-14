# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class TelephonesController < ::Sign::Org::ApplicationController
        include SignOperatorTelephoneRegistrable
        include ::SignSettingsAuthorityRedirect

        include ::VerificationOperator

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :open, only: %i(index destroy)
        declare_authentication_mode! :private, only: %i(new create edit)

        before_action :authenticate_operator!, except: %i(index destroy)
        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index = redirect_to_acme_settings_authority!

        def new
          @staff_telephone = OperatorTelephone.new
        end

        def edit
          @staff_telephone = current_operator.staff_telephones.find(params(:id))
          authorize!(@staff_telephone)
        end

        def create
          tel_params = params(staff_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]

          unless initiate_staff_telephone_verification(current_operator, number)
            render :new, status: :unprocessable_content
            return
          end

          redirect_to(edit_sign_org_settings_telephones_registration_path(ri: params[:ri]))
        end

        def destroy = redirect_to_acme_settings_authority!

        private

        def authorize_telephone_registration!
          authorize!(OperatorTelephone, to: :create?)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_telephone"
        end
      end
    end
  end
end
