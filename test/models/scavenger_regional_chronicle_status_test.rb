# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_regional_chronicle_statuses
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ScavengerRegionalChronicleStatusTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ScavengerRegionalChronicleStatus", ScavengerRegionalChronicleStatus.name
  end
end
