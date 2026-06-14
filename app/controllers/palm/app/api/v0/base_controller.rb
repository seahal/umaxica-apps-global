# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Api
      module V0
        # Palm API endpoints are bearer-token resource-server endpoints and do
        # not inherit browser/session callbacks from any HTML controller.
        class BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
          AUTHENTICATION_MODE = :bare

          protect_from_forgery using: :header_or_legacy_token, with: :exception

          before_action :skip_session_storage!
          before_action :set_no_store!

          private

          attr_reader :current_resource, :current_token_payload

          def authenticate_palm_bearer_token!
            result = PalmAccessTokenAuthenticator.call(
              access_token: authorization_access_token,
              host: request.host,
              authorization_scheme: authorization_scheme,
            )
            unless result.success?
              render_palm_authentication_error(result.error)
              return false
            end

            @current_resource = result.resource
            @current_token_payload = result.payload
            true
          end

          def render_palm_authentication_error(error)
            if error == "insufficient_scope"
              render_error(:authorization_denied, "Authorization denied.", status: :forbidden)
            else
              render_error(:authentication_required, "Authentication is required.", status: :unauthorized)
            end
          end

          def render_error(code, message, status:, fields: [])
            render(
              json: {
                error: {
                  code: code.to_s,
                  message: message,
                  request_id: request.request_id,
                  detail: nil,
                  fields: fields,
                },
              },
              status: status,
            )
          end

          def authorization_access_token
            AuthAuthorizationHeader.access_token(request)
          end

          def authorization_scheme
            request.authorization.to_s.split(/\s+/, 2).first
          end

          def skip_session_storage!
            request.session_options[:skip] = true
          end

          def set_no_store!
            response.set_header("Cache-Control", "no-store")
          end
        end
      end
    end
  end
end
