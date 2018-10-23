require "builder"
require "faraday"
require "faraday_middleware"
require "faraday_middleware/response/rashify"
require "hashie"
require "multi_xml"

# Errors
require "dhl/ecommerce/errors/base_error"
require "dhl/ecommerce/errors/authentication_error"
require "dhl/ecommerce/errors/validation_error"

# Operations
require "dhl/ecommerce/operations/find"
require "dhl/ecommerce/operations/list"

# Resources
require "dhl/ecommerce/base"
require "dhl/ecommerce/account"
require "dhl/ecommerce/event"
require "dhl/ecommerce/impb"
require "dhl/ecommerce/label"
require "dhl/ecommerce/location"
require "dhl/ecommerce/manifest"
require "dhl/ecommerce/product"
require "dhl/ecommerce/standard_address"
require "dhl/ecommerce/tracked_event"

# Version
require "dhl/ecommerce/version"

module DHL
  module Ecommerce
    class << self
      def client
        @client ||= Client.new(ENV["DHL_ECOMMERCE_CLIENT_ID"], username: ENV["DHL_ECOMMERCE_USERNAME"], password: ENV["DHL_ECOMMERCE_PASSWORD"], access_token: ENV["DHL_ECOMMERCE_ACCESS_TOKEN"])
      end

      def configure
        yield(client)
      end

      def request(*args)
        client.request(*args)
      end
    end

    class Client
      attr_accessor :client_id, :label_format
      attr_writer :access_token, :password, :username

      def initialize(client_id, options = {})
        options ||= {}
        @username = options[:username]
        @password = options[:password]
        @access_token = options[:access_token]
        @client_id = client_id
        @label_format = :png
        @refreshed_access_token = false
      end

      def access_token
        @access_token ||= refresh_access_token
      end

      def refresh_access_token
        @refreshed_access_token = true
        request("get", "https://api.dhlglobalmail.com/v1/auth/access_token", username: @username, password: @password, state: Time.now.to_i)[:access_token]
      end

      def request(method, url, params = nil, &block)
        client.params = params || {
          client_id: client_id,
          access_token: access_token
        }
        response = client.run_request method.downcase.to_sym, url, nil, nil, &block

        if response.status >= 300
          case response.body.response.meta.error.error_type
          when "INVALID_CLIENT_ID", "INVALID_KEY", "INVALID_TOKEN", "INACTIVE_KEY"
            if !@refreshed_access_token
              @access_token = nil
              retry
            end
            raise Errors::AuthenticationError.new response.body.response.meta.error.error_message, response
          when "VALIDATION_ERROR", "INVALID_FACILITY_CODE"
            errors = response.body.response.data.mpu_list.mpu.error_list.error
            errors = [errors] unless errors.is_a? Array

            raise Errors::ValidationError.new response.body.response.meta.error.error_message, response, errors
          else
            raise Errors::BaseError.new response.body.response.meta.error.error_message, response
          end
        end

        response.body.response.data
      end

      [ Account, Event, Label, Location, Product ].each do |model|
        safe_name = model.to_s.split("::").last.downcase
        define_method("#{safe_name}s") do
          model.all(self)
        end
        define_method("find_#{safe_name}") do |id|
          model.find(id, self)
        end
      end

      private

      def client
        @client ||= Faraday.new url: "https://api.dhlglobalmail.com/v1/", headers: { accept: "application/xml", content_type: "application/xml;charset=UTF-8" } do |c|
          c.response :rashify
          c.response :xml, :content_type => /\bxml$/
          c.adapter :net_http
        end
      end
    end
  end
end
