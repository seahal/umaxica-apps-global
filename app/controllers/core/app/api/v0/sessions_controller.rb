# typed: false
# frozen_string_literal: true

module Core
  module App
    module Api
      module V0
        class SessionsController < BaseController
          AUTHENTICATION_MODE = :bare

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
              id: actor_public_id,
              display_name: current_resource.try(:display_name).presence ||
                current_resource.try(:name).presence ||
                actor_public_id,
            }
          end

          # `public_id` is `null: false, default: ""`, so a record written around the model layer can
          # carry a blank one. The previous fallback answered that case with the database primary
          # key, putting an internal identifier on the public wire. Failing loudly is correct: a
          # blank `public_id` is a data-integrity fault, not a display problem.
          def actor_public_id
            current_resource.public_id.presence ||
              raise(BlankPublicIdentifierError.new(record_class: current_resource.class))
          end
        end
      end
    end
  end
end
