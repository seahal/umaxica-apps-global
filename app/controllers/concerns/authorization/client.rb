# typed: false
# frozen_string_literal: true

module Authorization
  module Client
    extend ActiveSupport::Concern

    include Authorization::Base
  end
end
