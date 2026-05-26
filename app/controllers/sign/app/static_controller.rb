# typed: false
# frozen_string_literal: true

module Sign
  module App
    class StaticController < BareController
      AUTHENTICATION_MODE = :bare
    end
  end
end
