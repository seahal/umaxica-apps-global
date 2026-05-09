# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Verification
      class SetupsController < Sign::Com::ApplicationController
        auth_required!

        before_action :authenticate_customer!

        def new
          @rd = params.expect(:rd).to_s.presence
        end
      end
    end
  end
end
