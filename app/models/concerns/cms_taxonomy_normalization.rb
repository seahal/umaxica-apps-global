# typed: false
# frozen_string_literal: true

module CmsTaxonomyNormalization
  module_function

  def normalize(value)
    value.to_s.unicode_normalize(:nfkc).downcase.strip.gsub(/\s+/, " ")
  end
end

module Cms
  TaxonomyNormalization = ::CmsTaxonomyNormalization
end
