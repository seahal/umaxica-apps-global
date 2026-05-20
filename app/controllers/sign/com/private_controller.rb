# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class PrivateController < ApplicationController
      auth_required!
    end
  end
end
