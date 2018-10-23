module DHL
  module Ecommerce
    class CustomsItem < Base
      attr_accessor :description, :country_of_origin, :hts_code, :quantity, :value, :sku

      def initialize(attributes = {})
        super attributes
      end
    end
  end
end
