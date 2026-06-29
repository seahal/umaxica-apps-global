# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class TelephonesController < BaseController
        include CommonRedirect
        include CommonOtp
        include SignTelephoneRegistrable
        include VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index
          @client_telephones = current_client.client_telephones.order(created_at: :asc)
          render "auth/app/settings/telephones/index"
        end

        def new
          @user_telephone = ClientTelephone.new
          render "auth/app/settings/telephones/new"
        end

        def edit
          @user_telephone = current_client.client_telephones.find_by!(public_id: params.expect(:id))
          authorize!(@user_telephone)
          render "auth/app/settings/telephones/edit"
        end

        def create
          user = current_client
          tel_params = params(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_telephone_verification(user, number, auto_accept_confirmations: true)
            redirect_to(edit_base_app_identity_telephones_registration_path(ri: params[:ri]), status: :see_other)
          else
            render :new, status: :unprocessable_content
          end
        end

        def destroy
          telephone = current_client.client_telephones.find_by!(public_id: params.expect(:id))
          authorize!(telephone)
          return redirect_to(
            base_app_identity_telephones_path(ri: params[:ri]),
            status: :see_other,
          ) unless AuthMethodGuard.can_remove_telephone?(
            current_client, telephone,
          )

          telephone.destroy!
          redirect_to(base_app_identity_telephones_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_telephone_registration! = authorize!(ClientTelephone, to: :create?)

        def verification_required_action? = true

        def verification_scope = "settings_telephone"
      end
    end
  end
end
