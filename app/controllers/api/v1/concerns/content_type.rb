module Api
  module V1
    module Concerns
      module ContentType
        extend ActiveSupport::Concern

        included do
          before_action :validate_content_type!
        end

        # default to JSON responses, disallow other Accept content types or format requests
        # will allow */*, application/json, or text/plain in any part of Accept header and respond with JSON
        def validate_content_type!
          accept_header = request.headers['Accept'].present? ? request.headers['Accept'] : ''
          if !accept_header.match(Regexp.union(%w(*/* application/json text/plain)))
            head 406
          else
            request.format = :json # override format to force JSON response
          end
        end
      end
    end
  end
end
