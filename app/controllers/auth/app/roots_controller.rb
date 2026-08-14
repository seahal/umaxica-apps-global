# typed: false
# frozen_string_literal: true

module Auth
  module App
    class RootsController < ::Auth::App::ApplicationController
      include ::RootSignInRedirect

      AUTHENTICATION_MODE = :open
      layout false

      redirect_root_to_sign_in { |region| auth_app_sign_in_path(ri: region) }

      def index
        redirect_to(after_login_path, allow_other_host: after_login_allows_other_host?) if logged_in?
      end
    end
  end
end
