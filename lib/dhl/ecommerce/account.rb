module DHL
  module Ecommerce
    class Account < Base
      include DHL::Ecommerce::Operations::Find
      include DHL::Ecommerce::Operations::List

      attr_reader :id, :address, :email

      def initialize(attributes = {})
        super attributes

        unless attributes.empty?
          @id = attributes[:account].to_i if attributes[:account]
          @address = StandardAddress.new attributes
        end
      end

      def locations
        response = client.request :get, "https://api.dhlglobalmail.com/v1/#{self.resource_name.downcase}s/#{id}/#{DHL::Ecommerce::Location.resource_name.downcase}s"
        response[self.resource_name]["#{DHL::Ecommerce::Location.resource_name}s"][DHL::Ecommerce::Location.resource_name] = [response[self.resource_name]["#{DHL::Ecommerce::Location.resource_name}s"][DHL::Ecommerce::Location.resource_name]] unless response[self.resource_name]["#{DHL::Ecommerce::Location.resource_name}s"][DHL::Ecommerce::Location.resource_name].is_a? Array

        response[self.resource_name]["#{DHL::Ecommerce::Location.resource_name}s"].map do |attributes|
          DHL::Ecommerce::Location.new attributes.merge(account: self, client: client)
        end
      end
    end
  end
end
