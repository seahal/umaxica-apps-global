# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_regional_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ScavengerRegionalChronicleEventTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ScavengerRegionalChronicleEvent", ScavengerRegionalChronicleEvent.name
  end
end
