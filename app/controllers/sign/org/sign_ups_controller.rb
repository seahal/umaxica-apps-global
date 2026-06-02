# typed: false
# frozen_string_literal: true

module Sign::Org
  class SignUpsController < Sign::Org::ApplicationController
    AUTHENTICATION_MODE = :guest
  end
end
