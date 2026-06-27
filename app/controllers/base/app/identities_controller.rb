# typed: false
# frozen_string_literal: true

module Base
  module App
    class IdentitiesController < Base::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def show
        authorize!(current_client, to: :show?)
        render "base/shared/identities/show", locals: { surface: :app, page_title: "Identity" }
      end
    end
  end
end
