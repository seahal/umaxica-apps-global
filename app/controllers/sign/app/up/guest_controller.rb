# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class GuestController < Sign::App::GuestController
        guest_only! status: :unauthorized, no_redirect: true
      end
    end
  end
end
