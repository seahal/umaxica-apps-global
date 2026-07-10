# typed: false
# frozen_string_literal: true

module Cms
  module TaxonomyNormalization
    module_function

    def normalize(value)
      value.to_s.unicode_normalize(:nfkc).downcase.strip.gsub(/\s+/, " ")
    end
  end
end
