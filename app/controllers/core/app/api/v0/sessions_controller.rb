# typed: false
# frozen_string_literal: true

module Core
  module App
    module Api
      module V0
        class SessionsController < BaseController
          def show
            authenticated = authenticate_core_browser_cookie!
            return if performed?

            payload = {
              authenticated: authenticated,
              csrf_token: form_authenticity_token,
            }
            payload[:actor] = actor_payload if authenticated

            render json: payload, status: :ok
          end

          private

          def actor_payload
            {
              id: current_resource.public_id.presence || current_resource.id.to_s,
              display_name: current_resource.try(:display_name).presence ||
                current_resource.try(:name).presence ||
                current_resource.try(:public_id).presence ||
                current_resource.id.to_s,
            }
          end
        end
      end
    end
  end
end
