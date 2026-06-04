# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class EmailsController < Sign::App::ApplicationController
        include ::Sign::SettingsAuthorityRedirect
        include ::Verification::Client

        AUTHENTICATION_MODE = :open

        def index
          return redirect_to_acme_emails! unless logged_in?

          @client_emails = current_client.client_emails
        end

        def edit = redirect_to_acme_email_edit!

        def update = redirect_to_acme_email!

        def destroy = redirect_to_acme_email!

        private

        def redirect_to_acme_emails!
          redirect_to_acme_authority!("/settings/emails")
        end

        def redirect_to_acme_email!
          redirect_to_acme_authority!("/settings/emails/#{params[:id]}")
        end

        def redirect_to_acme_email_edit!
          redirect_to_acme_authority!("/settings/emails/#{params[:id]}/edit")
        end

        def verification_required_action?
          return step_up_bootstrap_active? if action_name == "index"

          %w(edit update destroy).include?(action_name)
        end

        def verification_scope
          "settings_email"
        end
      end
    end
  end
end
