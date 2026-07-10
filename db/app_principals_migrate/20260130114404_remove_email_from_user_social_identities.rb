# frozen_string_literal: true

class RemoveEmailFromUserSocialIdentities < ActiveRecord::Migration[8.2]
  def change
    safety_assured { remove_column(:user_social_googles, :email, :string) }
    safety_assured { remove_column(:user_social_apples, :email, :string) }
  end
end
