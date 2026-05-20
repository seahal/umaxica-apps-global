# typed: false
# frozen_string_literal: true

module Sign
  module App
    class PrivateController < ApplicationController
      auth_required!
    end
  end
end
