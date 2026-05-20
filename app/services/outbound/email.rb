# typed: false
# frozen_string_literal: true

module Outbound
  class Email < ApplicationService
    def initialize(to:, title:, body:, **options)
      super()
      @to = to
      @title = title
      @body = body
      @options = options
    end

    def call
      Result.accepted(channel: :email)
    end

    private

    attr_reader :to, :title, :body, :options
  end
end
