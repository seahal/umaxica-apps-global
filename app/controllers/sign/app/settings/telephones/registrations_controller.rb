# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      module Telephones
        class RegistrationsController < ::Sign::App::ApplicationController
          include CloudflareTurnstile

          include CommonRedirect
          include CommonOtp
          include SignTelephoneRegistrable
          include SignSettingsTelephoneRegistration

          include ::VerificationClient

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          before_action :authenticate_client!
          # Object-level authorization (ActionPolicy): registering a telephone is a fresh-record action
          # for the authenticated client, so gate by actor type. Each step builds/looks up the record
          # for current_client. Verification/turnstile guards remain on the flow.
          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new = redirect_to(new_acme_app_identity_telephones_registration_path(ri: params[:ri]), status: :see_other)

          def edit
            redirect_to(
              edit_acme_app_identity_telephones_registration_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          def create = head(:gone)

          def update = head(:gone)

          private

          def authorize_telephone_registration!
            authorize!(ClientTelephone, to: :create?)
          end

          def verification_required_action? = false
        end
      end
    end
  end
end
