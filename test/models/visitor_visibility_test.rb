# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_visibilities
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorVisibilityTest < ActiveSupport::TestCase
  test "has visitor association" do
    assert_respond_to VisitorVisibility.new, :visitors
    assert_equal :has_many, VisitorVisibility.reflect_on_association(:visitors).macro
  end
end
