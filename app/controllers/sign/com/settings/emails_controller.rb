# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class EmailsController < ::Sign::Com::ApplicationController
        include ::SignSettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
      end
    end
  end
end
