# frozen_string_literal: true

class CreateExtensions < ActiveRecord::Migration[7.2]
  def up
    enable_extension('pgcrypto') unless extension_enabled?('pgcrypto')
  end

  def down
    disabl_extension('pgcrypto') unless extension_enabled?('pgcrypto')
  end
end
