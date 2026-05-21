# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class WelcomesController < PrivateController
      before_action :authenticate_visitor!
      before_action :continue_welcome_sequence_without_content!

      def show
      end
    end
  end
end
