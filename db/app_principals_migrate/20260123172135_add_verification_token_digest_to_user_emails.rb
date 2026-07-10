# frozen_string_literal: true

class AddVerificationTokenDigestToUserEmails < ActiveRecord::Migration[8.2]
  def change
    add_column(:user_emails, :verification_token_digest, :binary)
  end
end
