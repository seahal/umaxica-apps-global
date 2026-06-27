# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class WithdrawalsController < ::Auth::App::ApplicationController
        include ::VerificationClient
        include CommonRedirect
        include BaseSettingsWithdrawalFlow

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_withdrawal!, only: %i(new edit create update destroy)

        def new = redirect_to(new_base_app_identity_withdrawal_path(ri: params[:ri]), status: :see_other)

        def edit = redirect_to(edit_base_app_identity_withdrawal_path(ri: params[:ri]), status: :see_other)

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
