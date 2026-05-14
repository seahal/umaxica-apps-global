# typed: false
# frozen_string_literal: true

require "test_helper"

# Tests for ApplicationPolicy JWT integration via Actor.token
class ApplicationPolicyJwtTest < ActiveSupport::TestCase
  setup do
    Actor.reset
  end

  teardown do
    Actor.reset
  end

  class TestRecord
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  # JWT scopes from Actor.token
  def test_jwt_scopes_returns_empty_array_when_no_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_empty policy.send(:jwt_scopes)
  end

  def test_jwt_scopes_extracts_scopes_from_current_token
    Actor.token = {
      "scp" => ["authenticated", "domain:user", "read:self"],
    }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal ["authenticated", "domain:user", "read:self"], policy.send(:jwt_scopes)
  end

  def test_jwt_scopes_returns_empty_when_scp_missing
    Actor.token = { "sub" => 123 }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_empty policy.send(:jwt_scopes)
  end

  # has_scope? checks
  def test_has_scope_returns_true_when_scope_present
    Actor.token = { "scp" => ["authenticated", "read:self"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:has_scope?, "authenticated")
    assert policy.send(:has_scope?, "read:self")
  end

  def test_has_scope_returns_false_when_scope_missing
    Actor.token = { "scp" => ["authenticated"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_not policy.send(:has_scope?, "admin")
  end

  def test_has_scope_handles_symbol_arguments
    Actor.token = { "scp" => ["read:self"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:has_scope?, :"read:self")
  end

  # Domain extraction from audience
  def test_extract_domain_from_audience_returns_nil_without_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_nil policy.send(:extract_domain_from_audience)
  end

  def test_extract_domain_from_audience_extracts_domain
    Actor.token = { "aud" => ["app.api.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal "app", policy.send(:extract_domain_from_audience)
  end

  def test_extract_domain_from_audience_extracts_org_domain
    Actor.token = { "aud" => ["org.example.com", "api.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal "org", policy.send(:extract_domain_from_audience)
  end

  # Domain check helpers
  def test_domain_app_returns_true_for_app_domain
    Actor.token = { "aud" => ["app.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_app?)
    assert_not policy.send(:domain_org?)
    assert_not policy.send(:domain_com?)
  end

  def test_domain_org_returns_true_for_org_domain
    Actor.token = { "aud" => ["org.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_org?)
    assert_not policy.send(:domain_app?)
  end

  def test_domain_helpers_return_false_without_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_not policy.send(:domain_app?)
    assert_not policy.send(:domain_org?)
    assert_not policy.send(:domain_com?)
  end

  # domain_permitted? checks
  def test_domain_permitted_returns_true_when_allowed
    Actor.token = { "aud" => ["app.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_permitted?, "app")
    assert policy.send(:domain_permitted?, "app", "org")
  end

  def test_domain_permitted_returns_false_when_not_allowed
    Actor.token = { "aud" => ["app.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_not policy.send(:domain_permitted?, "org")
  end

  def test_domain_permitted_returns_true_when_no_domains_specified
    Actor.token = { "aud" => ["app.example.com"] }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_permitted?) # no restrictions
  end

  def test_domain_permitted_returns_true_when_domain_nil
    # If token has no audience or malformed, allow by default
    Actor.token = {}
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert policy.send(:domain_permitted?, "app")
  end

  # jwt_subject extraction
  def test_jwt_subject_returns_nil_without_token
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_nil policy.send(:jwt_subject)
  end

  def test_jwt_subject_extracts_subject
    Actor.token = { "sub" => 42 }
    policy = ApplicationPolicy.new(user: TestRecord.new(1))

    assert_equal 42, policy.send(:jwt_subject)
  end

  # Integration example: combining JWT + DB check
  def test_combining_jwt_and_db_check_example
    user = users(:one) # from fixtures
    Actor.token = {
      "sub" => user.id,
      "scp" => ["authenticated", "read:self", "domain:user"],
      "aud" => ["app.api.example.com"],
    }

    # Example: Policy that checks JWT scope AND DB ownership
    # Use a record that has user_id attribute for owner? check
    Struct.new(:user_id).new(user.id)
    policy = ApplicationPolicy.new(user: user)

    # Has correct scope?
    assert policy.send(:has_scope?, "read:self")

    # Correct domain?
    assert policy.send(:domain_app?)

    # Is owner? (DB check - record.user_id == actor.id)
    assert policy.send(:owner?)
  end
end
