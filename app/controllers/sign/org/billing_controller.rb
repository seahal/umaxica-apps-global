# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class BillingController < PrivateController
      before_action :authenticate_operator!

      def index
        render plain: "ok"
      end
    end
  end
end
