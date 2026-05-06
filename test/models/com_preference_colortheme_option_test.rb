# typed: false
# == Schema Information
#
# Table name: com_preference_colortheme_options
# Database name: setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"

class ComPreferenceColorthemeOptionTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
  end

  test "can be created" do
    option = ComPreferenceColorthemeOption.create!(id: 99)

    assert_not_nil option.id
  end

  test "has many com_preference_colorthemes" do
    option = ComPreferenceColorthemeOption.create!(id: 99)
    preference = ComPreference.create!
    colortheme = ComPreferenceColortheme.create!(preference: preference, option: option)

    assert_includes option.com_preference_colorthemes, colortheme
  end

  test "restricts deletion when associated records exist" do
    option = ComPreferenceColorthemeOption.create!(id: 99)
    preference = ComPreference.create!
    ComPreferenceColortheme.create!(preference: preference, option: option)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option.destroy!
    end
  end

  test "ensure_defaults! restores missing fixed ids" do
    com_preference_colorthemes(:one).destroy!
    com_preference_colortheme_options(:system).destroy!

    assert_not ComPreferenceColorthemeOption.exists?(ComPreferenceColorthemeOption::SYSTEM)

    ComPreferenceColorthemeOption.ensure_defaults!

    assert_equal ComPreferenceColorthemeOption::DEFAULTS,
                 ComPreferenceColorthemeOption.order(:id).pluck(:id)
  end
end
