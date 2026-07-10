# frozen_string_literal: true

class AddDivisionFkToClients < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    return unless table_exists?(:clients) && table_exists?(:divisions)
    return if foreign_key_exists?(:clients, :divisions)

    add_foreign_key(:clients, :divisions, validate: false)
    validate_foreign_key(:clients, :divisions)
  end

  def down
    return unless table_exists?(:clients) && table_exists?(:divisions)

    remove_foreign_key(:clients, :divisions) if foreign_key_exists?(:clients, :divisions)
  end
end
