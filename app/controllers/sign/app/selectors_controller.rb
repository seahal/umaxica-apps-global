# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SelectorsController < PrivateController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!
      before_action :continue_selector_sequence!

      def show
      end
    end
  end
end
