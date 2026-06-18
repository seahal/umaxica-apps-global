# typed: false
# frozen_string_literal: true

require "test_helper"

class ProsopiteInitializerTest < ActiveSupport::TestCase
  TEST_QUERY = 'SELECT "app_preferences"."id" FROM "app_preferences" ' \
    'WHERE "app_preferences"."public_id" = ' \
    "'abc123' LIMIT 1"

  test "fingerprint works while Active Record base is in reading role" do
    fingerprint =
      ActiveRecord::Base.connected_to(role: :reading) do
        Prosopite.fingerprint(TEST_QUERY)
      end

    assert_equal Prosopite.fingerprint(TEST_QUERY), fingerprint
  end

  test "fingerprint does not leave Active Record base in writing role" do
    ActiveRecord::Base.connected_to(role: :reading) do
      Prosopite.fingerprint(TEST_QUERY)

      assert_equal :reading, ActiveRecord::Base.current_role
    end
  end
end
