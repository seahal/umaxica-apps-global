# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Preference
      class EmailController < EmailsController
        AUTHENTICATION_MODE = :bare
      end
    end
  end
end
