# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_global_chronicle_statuses
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ScavengerGlobalChronicleStatusTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ScavengerGlobalChronicleStatus", ScavengerGlobalChronicleStatus.name
  end
end
