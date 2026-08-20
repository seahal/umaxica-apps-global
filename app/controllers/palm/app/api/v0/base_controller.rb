# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Api
      module V0
        # Palm API endpoints are bearer-token resource-server endpoints and do
        # not inherit browser/session callbacks from any HTML controller.
        class BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
          include ::ProblemDetailsRendering
          include ::ApiContentNegotiation
          include ::ApiV0LegacyErrorMember

          AUTHENTICATION_MODE = :bare

          protect_from_forgery using: :header_or_legacy_token, with: :exception

          before_action :skip_session_storage!
          before_action :set_no_store!

          private

          attr_reader :current_resource, :current_token_payload

          def authenticate_palm_bearer_token!
            if request.cookie_jar.to_hash.present? || request.headers["Cookie"].to_s.present?
              render_palm_authentication_error("invalid_token")
              return false
            end

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

          # RFC 6750 3.1 requires the bearer error to be named in `WWW-Authenticate`, which is where a
          # bearer client looks; the Problem Details document carries the same outcome for a human
          # reader. `insufficient_scope` is 403 and `invalid_token` is 401, per the same section.
          def render_palm_authentication_error(error)
            if error == "insufficient_scope"
              response.set_header("WWW-Authenticate", %(Bearer error="insufficient_scope"))
              render_problem(:authorization_denied)
            else
              response.set_header("WWW-Authenticate", %(Bearer error="invalid_token"))
              render_problem(:authentication_required)
            end
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
