# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ApplesController < Sign::App::ApplicationController
        include ::Verification::Client

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        def show
        end
      end
    end
  end
end
