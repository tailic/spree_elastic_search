module Spree
  module Search
    class ElasticSearch
      attr_accessor :properties
      attr_accessor :current_user
      attr_accessor :current_currency

      def initialize(params={})
        self.current_currency = Spree::Config[:currency]
        @properties = {}
        prepare(params)
      end

      def retrieve_products
        options = {
            facetFilters: facet_filters,
            tagFilters: tag_filters,
            facets: '*',
            page: page,
            hitsPerPage: per_page
            #properties: @property_params,
            #limit: params[:limit],
        }
        Rails.logger.warn ">>>>> #{options}"
        @products = Spree::Product.algolia_search(keywords, options)
      end

      def method_missing(name)
        if @properties.has_key? name
          @properties[name]
        else
          super
        end
      end

      protected

      def tag_filters
        taxon_name = taxon.name.try(:downcase) || nil
        "tagFilters: #{taxon_name}"
      end

      def facet_filters
        filters.collect do |k, v|
          [k, v].join(':')
        end
      end

      def prepare(params)
        @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
        @properties[:keywords] = params[:keywords]
        @properties[:search] = params[:search]
        @properties[:filters] = params.select{|k, v| Spree::Config.show_facets.keys.include?(k.to_sym) }

        per_page = params[:per_page].to_i
        @properties[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
        @properties[:page] = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
      end

    end
  end
end