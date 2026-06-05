# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      class ConnectionsController < Acme::App::ApplicationController
        include CloudflareTurnstile
        include Acme::Settings::OidcConnectionsManagement
        include ::Verification::Client

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :set_connection, only: %i(show destroy)
        before_action :authorize_connections!, only: %i(index show)
        before_action :authorize_social_link!, only: :social_link
        before_action :authorize_social_unlink!, only: :social_unlink
        before_action :authorize_connection_destroy!, only: :destroy
        helper_method :connection_status_label, :connection_scopes_text, :connection_last_used_text,
                      :connection_path_for, :connections_path, :settings_path

        def index
          super
          render "acme/app/settings/connections/index" unless performed?
        end

        def show
          super
          render "acme/app/settings/connections/show" unless performed?
        end

        def destroy = super

        def social_link
          provider = social_provider_param
          redirect_to(
            continue_sign_app_social_authentication_url(
              provider: provider,
              intent: "link",
              ri: params[:ri],
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            status: :see_other,
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def social_unlink
          provider = social_provider_param
          redirect_to(
            sign_app_social_authentication_url(
              provider: provider,
              ri: params[:ri],
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            status: :temporary_redirect,
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        private

        def authorize_social_link!
          authorize!(current_client, to: :update?)
        end

        def authorize_social_unlink!
          identity = social_identity_for_provider(params[:provider])
          if identity.present?
            authorize!(identity, to: :destroy?)
          else
            authorize!(current_client, to: :update?)
          end
        end

        def social_provider_param
          provider = params[:provider].to_s
          return provider if Identity::SocialCeremony::Contract::PROVIDERS.include?(provider)

          raise ActionController::BadRequest, "invalid social provider"
        end

        def social_identity_for_provider(provider)
          case SocialIdentifiable.normalize_provider(provider)
          when "apple"
            current_client.user_apple_identity
          when "google"
            current_client.user_google_identity
          end
        end

        def authorize_connections!
          authorize!(ClientOidcConnection, to: :index?)
        end

        def connections_scope
          current_client.oidc_connections
        end

        def connection_path_for(connection)
          acme_app_settings_connection_path(connection.public_id, ri: params[:ri])
        end

        def connections_path
          acme_app_settings_connections_path(ri: params[:ri])
        end

        def settings_path
          acme_app_settings_path(ri: params[:ri])
        end

        def verification_required_action?
          %w(social_link social_unlink).include?(action_name)
        end

        def verification_scope
          (action_name == "social_unlink") ? "social_unlink" : SocialAuthConcern::SOCIAL_LINK_SCOPE
        end
      end
    end
  end
end
