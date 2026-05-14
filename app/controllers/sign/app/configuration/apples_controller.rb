# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ApplesController < ApplicationController
        auth_required!

        include ::Verification::User

        before_action :authenticate_user!
        def show
        end
      end
    end
  end
end
