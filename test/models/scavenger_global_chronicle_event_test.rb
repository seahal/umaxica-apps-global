# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_global_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ScavengerGlobalChronicleEventTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ScavengerGlobalChronicleEvent", ScavengerGlobalChronicleEvent.name
  end
end
