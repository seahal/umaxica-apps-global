# frozen_string_literal: true

require_relative "support/cms_sample_builder"

# Loads explicit development-only CMS samples for every delivery family.
module CmsSamples
  module_function

  FAMILIES = {
    "AppDocs" => "app-docs-sample",
    "AppNews" => "app-news-sample",
    "AppInfo" => "app-info-sample",
    "AppHelp" => "app-help-sample",
    "ComDocs" => "com-docs-sample",
    "ComNews" => "com-news-sample",
    "ComInfo" => "com-info-sample",
    "ComHelp" => "com-help-sample",
    "OrgDocs" => "org-docs-sample",
    "OrgNews" => "org-news-sample",
    "OrgInfo" => "org-info-sample",
    "OrgHelp" => "org-help-sample",
  }.freeze

  def load!
    raise RuntimeError, "CMS samples are development-only" unless Rails.env.development?

    FAMILIES.each { |family, slug| CmsSampleBuilder.new(family:, slug:).create! }
  end
end
