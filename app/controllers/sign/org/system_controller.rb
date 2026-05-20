# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SystemController < PrivateController
      before_action :authenticate_operator!

      def index
        render plain: "ok"
      end
    end
  end
end
