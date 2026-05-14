# typed: false
# frozen_string_literal: true

module Authorization
  module Visitor
    extend ActiveSupport::Concern

    include Authorization::Base
  end
end
