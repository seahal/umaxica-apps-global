# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Verification
      class SetupsController < ApplicationController
        auth_required!

        before_action :authenticate_user!

        def new
          @rd = params.expect(:rd).to_s.presence
        end
      end
    end
  end
end
