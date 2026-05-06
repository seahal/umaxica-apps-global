# typed: false
# frozen_string_literal: true

require "test_helper"

class Authorization::ViewerTest < ActiveSupport::TestCase
  test "includes authorization base" do
    harness =
      Class.new do
        include Authorization::Viewer
      end

    assert_includes harness.included_modules, Authorization::Base
    assert harness.new.send(:authorize_request!)
  end
end
