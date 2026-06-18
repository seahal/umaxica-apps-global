# typed: false
# frozen_string_literal: true

module Sign
  module App
    class RootsController < ::Sign::App::ApplicationController
      AUTHENTICATION_MODE = :open
      layout false

      def index
        redirect_to(after_login_path, allow_other_host: after_login_allows_other_host?) if logged_in?
      end
    end
  end
end
