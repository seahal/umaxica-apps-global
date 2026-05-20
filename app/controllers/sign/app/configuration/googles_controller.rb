# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class GooglesController < PrivateController
        include ::Verification::Client

        before_action :authenticate_client!

        def show
        end
      end
    end
  end
end
