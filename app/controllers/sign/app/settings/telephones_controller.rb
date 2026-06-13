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
        declare_authentication_mode! :open, only: %i(index destroy)
        declare_authentication_mode! :private, only: %i(new create edit)

        before_action :authenticate_client!, except: %i(index destroy)
        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find_by! is owner-scoped, so a non-owner gets 404 first).
        # Verification guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def new
          @user_telephone = ClientTelephone.new
        end

        def edit
          @user_telephone = current_client.client_telephones.find_by!(public_id: params(:id))
          authorize!(@user_telephone)
        end

        def create
          user = current_client
          return head :unauthorized if user.blank?

          tel_params = params(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_telephone_verification(user, number, auto_accept_confirmations: true)
            redirect_to(edit_sign_app_settings_telephones_registration_path(ri: params[:ri]))
          else
            render :new, status: :unprocessable_content
          end
        end

        private

        def authorize_telephone_registration!
          authorize!(ClientTelephone, to: :create?)
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
