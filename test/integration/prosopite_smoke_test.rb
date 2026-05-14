# typed: false
# frozen_string_literal: true

require "test_helper"

class ProsopiteSmokeTest < ActionDispatch::IntegrationTest
  test "prosopite scans each test globally" do
    assert_predicate Prosopite, :scan?
  end

  test "prosopite raises for n+1 queries in integration tests" do
    created_user_ids =
      Prosopite.pause do
        3.times.map do |i|
          user = User.create!
          UserEmail.create!(user: user, address: "prosopite-smoke-#{i}-#{SecureRandom.hex(4)}@example.com")
          user.id
        end
      end

    error =
      Prosopite.pause do
        assert_raises(Prosopite::NPlusOneQueriesError) do
          Prosopite.scan do
            User.where(id: created_user_ids).order(:id).each do |user|
              user.user_emails.load
            end
          end
        end
      end

    # The global test hook also wraps this test, so clear its counters after
    # the focused local assertion to avoid a duplicate raise in teardown.
    Prosopite.pause do
      Prosopite.tc[:prosopite_query_counter] = Hash.new(0)
      Prosopite.tc[:prosopite_query_holder] = Hash.new { |h, k| h[k] = [] }
      Prosopite.tc[:prosopite_query_caller] = {}
    end

    assert_match(/N\+1/i, error.message)
  end
end
