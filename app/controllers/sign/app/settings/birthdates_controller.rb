# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class BirthdatesController < ::Sign::App::ApplicationController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def show = redirect_to(acme_app_identity_birthdate_path(ri: params[:ri]), status: :see_other)
      end
    end
  end
end
