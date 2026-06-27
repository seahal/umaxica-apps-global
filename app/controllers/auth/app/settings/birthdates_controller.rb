# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class BirthdatesController < ::Auth::App::ApplicationController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def show = redirect_to(base_app_identity_birthdate_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
