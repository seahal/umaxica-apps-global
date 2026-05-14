# typed: false
# frozen_string_literal: true

module Authorization
  module VisitorAccount
    extend ActiveSupport::Concern

    include Authentication::Base
  end
end
