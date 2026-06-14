# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Api
      module V0
        class ProfilesController < BaseController
          AUTHENTICATION_MODE = :bare

          before_action :authenticate_palm_bearer_token!

          def show
            return if performed?

            render(
              json: {
                actor: {
                  type: "client",
                  id: current_resource.public_id,
                },
              },
              status: :ok,
            )
          end
        end
      end
    end
  end
end
