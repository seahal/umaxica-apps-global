# typed: false
# frozen_string_literal: true

module Sign::Org
  class InsController < In::GuestController
    AUTHENTICATION_MODE = :guest

    def new
    end
  end
end
