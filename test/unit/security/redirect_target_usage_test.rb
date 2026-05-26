# frozen_string_literal: true

require "test_helper"

class RedirectTargetUsageTest < ActiveSupport::TestCase
  DIRECT_PARAM_REDIRECT = /redirect_to\s*\(?\s*params\[/.freeze
  DIRECT_ALLOW_OTHER_HOST = /allow_other_host:\s*true/.freeze

  ALLOW_OTHER_HOST_ALLOWLIST = %w[
    app/controllers/concerns/common/redirect.rb
  ].freeze

  test "controllers do not redirect directly to params" do
    offenders = ruby_files.grep(%r{\Aapp/controllers/}).select do |path|
      File.read(path).match?(DIRECT_PARAM_REDIRECT)
    end

    assert_empty offenders
  end

  test "allow_other_host true is limited to xt facade" do
    offenders = ruby_files.select do |path|
      next false if ALLOW_OTHER_HOST_ALLOWLIST.include?(path)

      File.read(path).match?(DIRECT_ALLOW_OTHER_HOST)
    end

    assert_empty offenders
  end

  private

  def ruby_files
    Dir.glob("{app,config,lib}/**/*.rb")
  end
end
