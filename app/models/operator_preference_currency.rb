# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_currencies
# Database name: org_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_operator_preference_currencies_on_option_id      (option_id)
#  index_operator_preference_currencies_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => operator_preference_currency_options.id)
#  fk_rails_...  (preference_id => operator_preferences.id)
#
class OperatorPreferenceCurrency < OrgPrincipalRecord
  belongs_to :preference, class_name: "OperatorPreference", inverse_of: :operator_preference_currency
  belongs_to :option,
             class_name: "OperatorPreferenceCurrencyOption",
             inverse_of: :operator_preference_currencies

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= OperatorPreferenceCurrencyOption::JPY
  end
end
