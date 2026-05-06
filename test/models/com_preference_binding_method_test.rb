# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_binding_methods
# Database name: setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceBindingMethodTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ComPreferenceBindingMethod", ComPreferenceBindingMethod.name
  end
end
