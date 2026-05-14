# typed: false
# frozen_string_literal: true

module Verification
  module Operator
    extend ActiveSupport::Concern

    include Verification::Base

    private

    def actor_operator?
      true
    end
  end
end
