# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        class SessionsController < BaseController
          AUTHENTICATION_MODE = :bare

          def show
            authenticated = authenticate_core_browser_cookie!
            return if performed?

            payload = { authenticated: authenticated, csrf_token: form_authenticity_token }
            payload[:actor] = { id: current_resource.public_id.presence || current_resource.id.to_s } if authenticated
            render json: payload, status: :ok
          end
        end
      end
    end
  end
end
