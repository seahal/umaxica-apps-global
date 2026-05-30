# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class BillingController < Sign::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate_operator!

      def index
        authorize!(current_operator, to: :billing?)

        render plain: "ok"
      end
    end
  end
end
