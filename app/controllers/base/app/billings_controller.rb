# typed: false
# frozen_string_literal: true

module Base
  module App
    class BillingsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def index
        authorize!(current_client, to: :show?)
        render "base/app/billings/index"
      end
    end
  end
end
