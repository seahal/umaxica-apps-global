# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Direct-message metadata and future message-domain records.
class MessageRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :message, reading: :message_replica }
end
