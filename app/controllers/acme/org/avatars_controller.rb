# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class AvatarsController < Acme::Org::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def show
        authorize!(current_operator, to: :show?)
        render "acme/shared/self_service/show", locals: { page_title: "Avatar" }
      end
    end
  end
end
