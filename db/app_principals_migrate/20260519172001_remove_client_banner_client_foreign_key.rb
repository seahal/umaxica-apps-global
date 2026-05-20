# frozen_string_literal: true

class RemoveClientBannerClientForeignKey < ActiveRecord::Migration[8.2]
  def change
    remove_foreign_key :client_banners, :clients
  end
end
