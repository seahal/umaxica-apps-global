# typed: false
# frozen_string_literal: true

require "test_helper"

class ProblemTypeTest < ActiveSupport::TestCase
  test "an unregistered slug raises instead of inventing a type URI" do
    error = assert_raises(KeyError) { ProblemType.fetch(:not_a_real_problem) }

    assert_match(/unregistered problem type/, error.message)
  end

  test "the URI is the hyphenated slug under the umaxica problem namespace" do
    assert_equal "urn:umaxica:problem:authentication-required", ProblemType.fetch(:authentication_required).uri
    assert_equal "urn:umaxica:problem:not-found", ProblemType.fetch(:not_found).uri
  end

  test "the status member is the numeric code matching the registered status" do
    assert_equal 401, ProblemType.fetch(:authentication_required).status_code
    assert_equal 403, ProblemType.fetch(:authorization_denied).status_code
    assert_equal 422, ProblemType.fetch(:validation_failed).status_code
    assert_equal 429, ProblemType.fetch(:rate_limited).status_code
  end

  test "every registered type resolves to a distinct URI" do
    uris = ProblemType::DEFINITIONS.each_key.map { |slug| ProblemType.fetch(slug).uri }

    assert_equal uris.uniq, uris
  end

  test "every registered status is a status Rack recognizes" do
    ProblemType::DEFINITIONS.each_key do |slug|
      assert_kind_of Integer, ProblemType.fetch(slug).status_code, "#{slug} has an unusable status"
    end
  end

  test "a string slug resolves to the same type as its symbol" do
    assert_equal ProblemType.fetch(:token_expired), ProblemType.fetch("token_expired")
  end

  test "registered? reports membership without raising" do
    assert ProblemType.registered?(:rate_limited)
    assert_not ProblemType.registered?(:not_a_real_problem)
  end

  test "for_status resolves every mapped status to a type carrying that status" do
    ProblemType::STATUS_FALLBACKS.each do |code, slug|
      problem = ProblemType.for_status(code)

      assert_equal slug, problem.slug
      assert_equal code, problem.status_code, "#{slug} does not carry status #{code}"
    end
  end

  test "for_status never raises on an unmapped status" do
    # It runs while an error is already being rendered, so raising would replace a reportable
    # failure with an unreportable one.
    assert_equal :bad_request, ProblemType.for_status(418).slug
    assert_equal :server_error, ProblemType.for_status(507).slug
  end

  test "every status shared by two types resolves to the more general one" do
    assert_equal :authentication_required, ProblemType.for_status(401).slug
    assert_equal :authorization_denied, ProblemType.for_status(403).slug
  end
end
