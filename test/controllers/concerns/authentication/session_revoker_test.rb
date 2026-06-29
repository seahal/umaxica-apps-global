# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationSessionRevokerTest < ActiveSupport::TestCase
  class FakeRelation
    def initialize(tokens)
      @tokens = tokens
    end

    def find_each
      @tokens.each { |token| yield token }
    end
  end

  class FakeToken
    attr_reader :revoke_calls

    def initialize
      @revoke_calls = 0
    end

    def revoke!
      @revoke_calls += 1
    end
  end

  test "tokens_for returns the matching token relation for each resource type" do
    user = Client.new(id: 1)
    staff = Operator.new(id: 2)
    visitor = Visitor.new(id: 3)

    assert_equal ClientToken.where(user_id: 1).to_sql, AuthenticationSessionRevoker.tokens_for(user).to_sql
    assert_equal OperatorToken.where(staff_id: 2).to_sql, AuthenticationSessionRevoker.tokens_for(staff).to_sql
    assert_equal VisitorToken.where(visitor_id: 3).to_sql, AuthenticationSessionRevoker.tokens_for(visitor).to_sql
  end

  test "tokens_for rejects unsupported resource types" do
    error = assert_raises(ArgumentError) { AuthenticationSessionRevoker.tokens_for(Object.new) }

    assert_match(/Unsupported resource type/, error.message)
  end

  test "revoke_all_for revokes each token from the relation" do
    tokens = [FakeToken.new, FakeToken.new]
    relation = FakeRelation.new(tokens)

    AuthenticationSessionRevoker.stub(:tokens_for, relation) do
      AuthenticationSessionRevoker.revoke_all_for(Client.new(id: 1))
    end

    assert_equal [1, 1], tokens.map(&:revoke_calls)
  end
end
