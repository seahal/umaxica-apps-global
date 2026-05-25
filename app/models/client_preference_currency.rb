# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_currencies
# Database name: app_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_client_preference_currencies_on_option_id      (option_id)
#  index_client_preference_currencies_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => client_preference_currency_options.id)
#  fk_rails_...  (preference_id => client_preferences.id)
#
class ClientPreferenceCurrency < AppPrincipalRecord
  belongs_to :preference, class_name: "ClientPreference", inverse_of: :client_preference_currency
  belongs_to :option,
             class_name: "ClientPreferenceCurrencyOption",
             inverse_of: :client_preference_currencies

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= ClientPreferenceCurrencyOption::JPY
  end
end
