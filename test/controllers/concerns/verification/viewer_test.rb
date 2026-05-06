# typed: false
# frozen_string_literal: true

require "test_helper"

class Verification::ViewerTest < ActiveSupport::TestCase
  test "includes verification base" do
    harness =
      Class.new do
        include Verification::Viewer
      end

    assert_includes harness.included_modules, Verification::Base
  end

  test "enforce_verification_if_required returns true when actor is not logged in" do
    harness =
      Class.new do
        include Verification::Viewer

        define_method(:logged_in?) do
          false
        end
      end

    assert harness.new.send(:enforce_verification_if_required)
  end
end
