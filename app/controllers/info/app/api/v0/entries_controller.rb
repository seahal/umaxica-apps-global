# typed: false
# frozen_string_literal: true

module Info
  module App
    module Api
      module V0
        class EntriesController < Info::App::BareController
          AUTHENTICATION_MODE = :bare

          def index
            render json: {
              entries: [
                {
                  slug: "terms",
                  title: "Sample Terms",
                  summary: "Sample public information entry.",
                  locale: "en",
                  status: "sample",
                },
                {
                  slug: "privacy",
                  title: "Sample Privacy",
                  summary: "Sample public information entry.",
                  locale: "en",
                  status: "sample",
                },
              ],
              surface: "info",
              namespace: "app",
              host: request.host,
              sample: true,
            }
          end

          def show
            render json: {
              entry: {
                slug: params.fetch(:slug),
                title: "Sample Info Entry",
                summary: "This is a sample response from the Info API stub.",
                body: "Sample body. Real content lookup is not implemented yet.",
                body_format: "plain",
                locale: "en",
                status: "sample",
              },
              surface: "info",
              namespace: "app",
              host: request.host,
              sample: true,
            }
          end
        end
      end
    end
  end
end
