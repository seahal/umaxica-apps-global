# typed: false
# frozen_string_literal: true

require "test_helper"

class TokenDeletableSyncTest < ActiveSupport::TestCase
  class MissingExpiryToken
    def self.before_validation(*) = nil

    def self.scope(*) = nil

    include TokenDeletableSync

    def has_attribute?(name)
      name.to_sym == :deletable_at
    end
  end

  test "raises when no expires_at style attribute exists" do
    token = MissingExpiryToken.new

    assert_raises(ArgumentError) { token.send(:expiry_attribute_name) }
  end
end
