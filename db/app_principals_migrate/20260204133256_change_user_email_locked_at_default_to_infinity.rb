# frozen_string_literal: true

class ChangeUserEmailLockedAtDefaultToInfinity < ActiveRecord::Migration[8.2]
  def change
    change_column_default(:user_emails, :locked_at, from: -::Float::INFINITY, to: ::Float::INFINITY)
  end
end
