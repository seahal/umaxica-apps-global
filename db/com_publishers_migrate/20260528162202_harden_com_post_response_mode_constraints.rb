# frozen_string_literal: true

class HardenComPostResponseModeConstraints < ActiveRecord::Migration[8.2]
  def up
    %i[posts post_versions post_revisions].each do |table|
      add_constraint_unless_exists(table, response_mode_sql, "chk_#{table}_response_mode")
      add_constraint_unless_exists(table, redirect_url_sql, "chk_#{table}_redirect_url_for_redirect")
    end
  end

  def down
    %i[posts post_versions post_revisions].each do |table|
      remove_check_constraint(table, name: "chk_#{table}_response_mode", if_exists: true)
      remove_check_constraint(table, name: "chk_#{table}_redirect_url_for_redirect", if_exists: true)
    end
  end

  private

  def add_constraint_unless_exists(table, expression, name)
    return if check_constraint_exists?(table, name: name)

    add_check_constraint(table, expression, name: name, validate: false)
  end

  def response_mode_sql = "response_mode IN ('html', 'text', 'pdf', 'redirect')"

  def redirect_url_sql = "response_mode <> 'redirect' OR redirect_url IS NOT NULL"
end
