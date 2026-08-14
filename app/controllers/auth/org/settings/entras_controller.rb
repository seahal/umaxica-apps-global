# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      class EntrasController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :authorize_entra_settings!
        before_action :set_entra_identity, only: %i(show edit)
        before_action :set_entra_connections, only: %i(show edit)

        def show
          render inertia: true, props: entra_show_props
        end

        def edit
          render inertia: true, props: entra_edit_props
        end

        def create
          connection = OrganizationEntraConnection.find_by!(
            public_id: entra_params.fetch(:connection_public_id),
            status_id: OrganizationEntraConnectionState::ACTIVE,
          )

          redirect_to(
            new_auth_org_social_entra_session_path(connection: connection.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def destroy
          set_entra_identity
          set_entra_connections
          render inertia: "auth/org/settings/entras/edit",
                 props: entra_edit_props,
                 status: :unprocessable_content
        end

        private

        def entra_show_props
          {
            title: "Microsoft Entra ID",
            heading: "Microsoft Entra ID",
            back_link: { label: t("sign.app.settings.show.back"), href: auth_org_settings_path(ri: params[:ri]) },
            status: @entra_identity.present? ? "Connected" : "Not connected",
            edit_link: { label: t("actions.edit"), href: edit_auth_org_settings_entra_path(ri: params[:ri]) },
          }
        end

        # Disconnecting from settings is not offered until the operator lifecycle owner is defined,
        # so a connected identity gets the notice and no form at all.
        def entra_edit_props
          connected = @entra_identity.present?

          {
            title: "Microsoft Entra ID",
            heading: "Microsoft Entra ID",
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_org_settings_entra_path(ri: params[:ri]),
            },
            connected: connected,
            connected_notice: if connected
                                "Disconnecting Microsoft Entra ID from settings is not available " \
                                  "until the operator lifecycle owner is defined."
                              end,
            empty_notice: ("No active Microsoft Entra ID connection is available." if !connected && @entra_connections.empty?),
            form_action: auth_org_settings_entra_path(ri: params[:ri]),
            submit_label: "Connect",
            connections: if connected
                           []
                         else
                           @entra_connections.map { |connection| { public_id: connection.public_id } }
                         end,
          }
        end

        def authorize_entra_settings!
          authorize!(current_operator, to: :show?)
        end

        def set_entra_identity
          @entra_identity = OperatorEntraIdentity.find_by(
            operator_id: current_operator.id,
            status_id: OperatorEntraIdentityState::ACTIVE,
          )
        end

        def set_entra_connections
          @entra_connections = OrganizationEntraConnection.where(
            status_id: OrganizationEntraConnectionState::ACTIVE,
          ).order(created_at: :asc)
        end

        def entra_params
          params.expect(entra: [:connection_public_id])
        end
      end
    end
  end
end
