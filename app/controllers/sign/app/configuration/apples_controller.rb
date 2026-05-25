# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ApplesController < PrivateController
        AUTHENTICATION_MODE = :private

        include ::Verification::Client

        before_action :authenticate_client!
        def show
        end
      end
    end
  end
end
