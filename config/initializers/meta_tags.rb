# typed: false
# frozen_string_literal: true

MetaTags.configure do |config|
  config.title_limit = 70
  config.truncate_site_title_first = false
  # Must match the EM DASH separator the layouts pass to display_meta_tags, so a
  # truncated title breaks at the brand boundary instead of mid-word.
  config.truncate_on_natural_separator = "—"
end
