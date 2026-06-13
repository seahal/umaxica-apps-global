# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: news_content_entries
# Database name: app_zenith
#
#  id           :bigint           not null, primary key
#  body         :text             not null
#  locale       :string           not null
#  published_at :datetime
#  slug         :string           not null
#  status       :string           default("draft"), not null
#  summary      :text
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_news_content_entries_on_locale_and_slug          (locale,slug) UNIQUE
#  index_news_content_entries_on_status_and_published_at  (status,published_at)
#
module News
  module App
    class ContentEntry < AppRpRecord
      include ReadOnlyContentEntry

      self.table_name = "news_content_entries"
    end
  end
end
