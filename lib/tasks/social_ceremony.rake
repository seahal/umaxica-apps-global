# frozen_string_literal: true

# Operates the external authentication kill switches now held in Flipper.
# Provider names match ExternalAuthentication::FlipperProviderAvailabilityAdapter.
social_ceremony_feature =
  lambda do |provider|
    features = ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES
    features.fetch(provider) do
      abort("unknown provider #{provider.inspect}; expected one of #{features.keys.join(", ")}")
    end
  end

namespace :social_ceremony do
  desc "Enable a social ceremony provider (apple, google, entra)"
  task :enable, [:provider] => :environment do |_task, args|
    feature = social_ceremony_feature.call(args.fetch(:provider))
    Flipper.enable(feature)
    puts "#{feature}: enabled"
  end

  desc "Disable a social ceremony provider (apple, google, entra)"
  task :disable, [:provider] => :environment do |_task, args|
    feature = social_ceremony_feature.call(args.fetch(:provider))
    Flipper.disable(feature)
    puts "#{feature}: disabled"
  end

  desc "Show the current state of every social ceremony provider"
  task status: :environment do
    ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES
      .each_value { |feature| puts "#{feature}: #{Flipper.enabled?(feature) ? "enabled" : "disabled"}" }
  end
end
