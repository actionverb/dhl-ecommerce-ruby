module DHL
  module Ecommerce
    class Manifest < Base
      attr_reader :id, :location_id

      def location_id=(location_id)
        @location = nil
        @location_id = location_id
      end

      def location
        @location ||= DHL::Ecommerce::Location.find(location_id, client)
      end

      def file
        @base64_decoded_file ||= StringIO.new(Base64.decode64(@file))
      end

      def self.create(labels, client = DHL::Ecommerce.client)
        labels.group_by(&:location_id).each.collect do |location_id, location_labels|
          closeout_id = client.request :get, "https://api.dhlglobalmail.com/v1/#{DHL::Ecommerce::Location.resource_name.downcase}s/#{location_id}/closeout/id"

          location_labels.each_slice(500) do |slice_labels|
            xml = Builder::XmlMarkup.new
            xml.instruct! :xml, version: "1.1", encoding: "UTF-8"

            xml.ImpbList do
              slice_labels.each do |label|
                xml.Impb do
                  xml.Construct label.impb.construct
                  xml.Value label.impb.value
                end
              end
            end

            client.request :post, "https://api.dhlglobalmail.com/v1/#{DHL::Ecommerce::Location.resource_name.downcase}s/#{location_id}/closeout/#{closeout_id}" do |request|
              request.body = xml.target!
            end
          end

          response = client.request :get, "https://api.dhlglobalmail.com/v1/#{DHL::Ecommerce::Location.resource_name.downcase}s/#{location_id}/closeout/#{closeout_id}"
          response[:manifest_list][:manifest] = [response[:manifest_list][:manifest]] unless response[:manifest_list][:manifest].is_a? Array
          response[:manifest_list][:manifest].each.collect do |attributes|
            new attributes.merge(location_id: location_id)
          end
        end.flatten
      end

      def self.create_v2(labels, client = DHL::Ecommerce.client)
        labels.group_by(&:location_id).each.map { |location_id, location_labels|
          json = { "closeoutRequests": [ {
            "packages": location_labels.map { |label|
              { "packageId": label.customer_confirmation_number }
            }
          } ] }.to_json

          url = "https://api.dhlglobalmail.com/v2/locations/#{location_id}/closeout/multi"
          response = client.request(:post, url, nil, :v2) do |request|
            request.body = json
          end

          response[:data].first[:closeouts].first[:manifests].map { |manifest|
            new manifest.merge(location_id: location_id)
          }
        }.flatten
      end
    end
  end
end
