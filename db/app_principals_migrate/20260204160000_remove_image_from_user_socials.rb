# frozen_string_literal: true

class RemoveImageFromUserSocials < ActiveRecord::Migration[8.2]
  def change
    safety_assured { remove_column(:user_social_apples, :image, :string) }
    safety_assured { remove_column(:user_social_googles, :image, :string) }
  end
end
