# typed: false
# frozen_string_literal: true

module Palm
  module App
    class SignOutsController < Palm::App::BareController
      AUTHENTICATION_MODE = :bare

      def show
      end

      def create
        reset_session
        redirect_to(palm_app_root_path, status: :see_other)
      end
    end
  end
end
