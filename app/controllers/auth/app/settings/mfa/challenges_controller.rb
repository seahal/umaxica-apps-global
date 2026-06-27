# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      module Mfa
        class ChallengesController < ::Auth::App::ApplicationController
          include ::VerificationClient

          AUTHENTICATION_MODE = :private

          before_action :authenticate_client!
          # Object-level authorization (ActionPolicy): the MFA level is an account-self attribute
          # on the client, so only the owner may view/update it. Reuses ClientPolicy#show?/#update?
          # (owner-self), mirroring the birthdate page. Step-up/verification guards remain below.
          before_action :authorize_mfa_challenge!, only: %i(show update)

          def show = redirect_to(base_app_identity_mfa_challenge_path(ri: params[:ri]), status: :see_other)

          def update = head(:gone)

          private

          def authorize_mfa_challenge! = authorize!(current_client, to: :"#{action_name}?")

          def verification_required_action? = false
        end
      end
    end
  end
end
