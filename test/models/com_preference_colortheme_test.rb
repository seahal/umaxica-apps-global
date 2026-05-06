# typed: false
# == Schema Information
#
# Table name: com_preference_colorthemes
# Database name: setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_com_preference_colorthemes_on_option_id      (option_id)
#  index_com_preference_colorthemes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_com_preference_colorthemes_on_option_id  (option_id => com_preference_colortheme_options.id)
#  fk_rails_...                                (preference_id => com_preferences.id)
#

# frozen_string_literal: true

require "test_helper"

class ComPreferenceColorthemeTest < ActiveSupport::TestCase
  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
    @preference = ComPreference.create!(status_id: ComPreferenceStatus::NOTHING)
  end

  test "belongs to preference" do
    colortheme = ComPreferenceColortheme.new

    assert_not colortheme.valid?
    assert_predicate colortheme.errors[:preference], :any?, "Expected preference error to be present"
  end

  test "can be created with preference and option" do
    option = com_preference_colortheme_options(:light)
    colortheme = ComPreferenceColortheme.create!(preference: @preference, option: option)

    assert_not_nil colortheme.id
    assert_equal @preference, colortheme.preference
    assert_equal option, colortheme.option
  end

  test "sets default option_id on create" do
    colortheme = ComPreferenceColortheme.create!(preference: @preference)

    assert_equal ComPreferenceColorthemeOption::SYSTEM, colortheme.option_id
  end
end
