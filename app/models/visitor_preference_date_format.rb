# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_date_formats
# Database name: com_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_visitor_preference_date_formats_on_option_id      (option_id)
#  index_visitor_preference_date_formats_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => visitor_preference_date_format_options.id)
#  fk_rails_...  (preference_id => visitor_preferences.id)
#
class VisitorPreferenceDateFormat < ComPrincipalRecord
  belongs_to :preference, class_name: "VisitorPreference", inverse_of: :visitor_preference_date_format
  belongs_to :option,
             class_name: "VisitorPreferenceDateFormatOption",
             inverse_of: :visitor_preference_date_formats

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= VisitorPreferenceDateFormatOption::ISO
  end
end
