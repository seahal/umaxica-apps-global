# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorStatusTest < ActiveSupport::TestCase
  test "has visitor association" do
    assert_respond_to VisitorStatus.new, :visitors
    assert_equal :has_many, VisitorStatus.reflect_on_association(:visitors).macro
  end
end
