# typed: false
# frozen_string_literal: true

module Sign
  module App
    class WelcomesController < PrivateController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_client!
      before_action :continue_welcome_sequence_without_content!

      def show
      end
    end
  end
end
