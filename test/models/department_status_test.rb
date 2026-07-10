# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: department_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class DepartmentStatusTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "DepartmentStatus", DepartmentStatus.name
  end
end
