# typed: false
# frozen_string_literal: true

module Robots
  extend ActiveSupport::Concern

  private

  def show_plain_text
    render plain: robots_txt
  end

  def robots_txt
    "User-agent: *\nDisallow:\n"
  end
end
