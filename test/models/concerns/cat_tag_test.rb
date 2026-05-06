# typed: false
# frozen_string_literal: true

require "test_helper"

class CatTagTest < ActiveSupport::TestCase
  test "is an Active Support concern" do
    assert_includes CatTag.singleton_class.ancestors, ActiveSupport::Concern
  end
end
