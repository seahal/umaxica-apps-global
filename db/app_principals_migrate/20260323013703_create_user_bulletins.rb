# frozen_string_literal: true

class CreateUserBulletins < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_table(:user_bulletins, id: :bigserial) do |t|
        t.bigint(:user_id, null: false)
        t.string(:public_id, limit: 21, null: false)
        t.string(:title, null: false)
        t.text(:body)
        t.datetime(:read_at)

        t.timestamps
      end

      add_index(:user_bulletins, :user_id)
      add_index(:user_bulletins, :public_id, unique: true)
      add_foreign_key(:user_bulletins, :users)
    end
  end
end
