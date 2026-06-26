# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class WithdrawalsController < ::Sign::App::ApplicationController
        include ::VerificationClient
        include CommonRedirect
        include AcmeSettingsWithdrawalFlow

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_withdrawal!, only: %i(new edit create update destroy)

        def new = redirect_to(new_acme_app_identity_withdrawal_path(ri: params[:ri]), status: :see_other)

        def edit = redirect_to(edit_acme_app_identity_withdrawal_path(ri: params[:ri]), status: :see_other)

        def create = head(:gone)

        def update = head(:gone)

        def destroy = head(:gone)

        private

        def authorize_withdrawal! = authorize!(current_client, to: :"#{action_name}?", with: ClientWithdrawalPolicy)

        def verification_required_action? = false
      end
    end
  end
end
