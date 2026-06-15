# typed: false
# frozen_string_literal: true

require "json"

namespace :content do
  desc "Import read-only content entries from JSONL: content:import[namespace,surface,path]"
  task :import, %i(namespace surface path) => :environment do |_task, args|
    namespace = args.fetch(:namespace).to_s
    surface = args.fetch(:surface).to_s
    path = args.fetch(:path).to_s

    unless %w(docs news help).include?(namespace)
      raise ArgumentError, "namespace must be one of docs, news, or help"
    end

    unless %w(app com org).include?(surface)
      raise ArgumentError, "surface must be one of app, com, or org"
    end

    model = "#{namespace}_#{surface}_content_entry".camelize.constantize
    imported = 0

    File.foreach(path) do |line|
      next if line.blank?

      payload = JSON.parse(line)
      entry = model.find_or_initialize_by(
        locale: payload.fetch("locale"),
        slug: payload.fetch("slug"),
      )
      entry.assign_attributes(
        title: payload.fetch("title"),
        summary: payload["summary"],
        body: payload.fetch("body"),
        status: payload.fetch("status", "draft"),
        published_at: payload["published_at"],
      )
      entry.save!
      imported += 1
    end

    puts "Imported #{imported} #{namespace}/#{surface} content entries"
  end
end
