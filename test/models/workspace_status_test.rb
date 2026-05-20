# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: workspace_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class WorkspaceStatusTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, WorkspaceStatus::NOTHING
    assert_equal 1, WorkspaceStatus::LEGACY_NOTHING
  end

  test "can load nothing status from db" do
    status = WorkspaceStatus.find(WorkspaceStatus::NOTHING)

    assert_equal 0, status.id
  end

  test "defaults includes all fixed ids" do
    assert_includes WorkspaceStatus::DEFAULTS, WorkspaceStatus::NOTHING
    assert_includes WorkspaceStatus::DEFAULTS, WorkspaceStatus::LEGACY_NOTHING
  end

  test "ensure_defaults! creates missing default records" do
    WorkspaceStatus.where(id: WorkspaceStatus::NOTHING).destroy_all

    assert_difference("WorkspaceStatus.count") do
      WorkspaceStatus.ensure_defaults!
    end
  end

  test "ensure_defaults! skips when all defaults exist" do
    WorkspaceStatus.ensure_defaults!

    assert_no_difference("WorkspaceStatus.count") do
      WorkspaceStatus.ensure_defaults!
    end
  end
end
