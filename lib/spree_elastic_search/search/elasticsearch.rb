module AdditionalMethods
  def self.extended(base)
    class <<base
      alias_method :raw_answer, :algolia_raw_answer unless method_defined? :raw_answer
      alias_method :facets, :algolia_facets unless method_defined? :facets
    end
  end

  def algolia_raw_answer
    @algolia_json
  end

  def algolia_facets
    @algolia_json['facets']
  end

  def algolia_disjuctive_facets
    @algolia_json['disjunctiveFacets']
  end

  private
  def algolia_init_raw_answer(json)
    @algolia_json = json
  end
end

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
        query = keywords || ''
        disjunctive = Spree::Config.disjunctive_facets
        @products = algolia_products_search(query, disjunctive)
      end

      def algolia_products_search(query, disjunctive)
        page = search_params[:page]
        page -= 1 if page > 0
        json = Spree::Product.algolia_raw_search_disjunctive_faceting(query, disjunctive, search_params.merge({page: page}), refinements)
        results = json['hits'].collect{ |h| Spree::AlgoliaProduct.new(h) }.compact
        fake_hits = [json['nbHits'].to_i, 1000].min
        res = AlgoliaSearch::Pagination.create(results, fake_hits, { :page => json['page'] + 1, :per_page => json['hitsPerPage'] })
        res.extend(AdditionalMethods)
        res.send(:algolia_init_raw_answer, json)
        res
      end

      def prices
        disjunctive_facets['price_per'].keys.map{|k| k.to_d }.sort
      end

      def facets
        @products.algolia_raw_answer['facets']
      end

      def disjunctive_facets
        @products.algolia_raw_answer['disjunctiveFacets']
      end

      def search_request
        query = keywords || ''
        disjunctive = Spree::Config.disjunctive_facets
        {
            query: query,
            disjunctiveFacets: disjunctive,
            params: search_params,
            refinements: refinements,
            preis_von: price_filters['preis_von'].try(:to_d),
            preis_bis: price_filters['preis_bis'].try(:to_d)
        }
      end

      def method_missing(name)
        if @properties.has_key? name
          @properties[name]
        else
          super
        end
      end

      protected

      def search_params
        {
            facetFilters: facet_filters,
            tagFilters: tag_filters,
            facets: '*',
            maxValuesPerFacet: 9999999999,
            numericFilters: numeric_filters,
            page: page ,
            hitsPerPage: per_page
        }
      end

      def refinements
        filters
      end

      def tag_filters
        if taxon
          taxon_name = taxon.permalink.split('/').last || nil
          return [taxon_name]
        end
        nil
      end

      def facet_filters
        filters.collect do |k, v|
          [k, v].join(':')
        end
      end

      def numeric_filters
        filters = []
        if price_filters['preis_von'].present? && price_filters['preis_bis'].present?
          filters << "price_per:#{price_filters['preis_von'].to_d} to #{price_filters['preis_bis'].to_d}"
        elsif price_filters['preis_von'].present? && price_filters['preis_bis'].blank?
          filters << "price_per>=#{price_filters['preis_von'].to_d}"
        elsif price_filters['preis_von'].blank? && price_filters['preis_bis'].present?
          filters << "price_per<=#{price_filters['preis_bis'].to_d}"
        end
        filters.join(',')
      end

      def prepare(params)
        @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
        @properties[:keywords] = params[:keywords]
        @properties[:search] = params[:search]
        @properties[:filters] = params.select{|k, v| (Spree::Config.show_facets.merge(:hersteller => 'Hersteller')).keys.include?(k.to_sym) }
        @properties[:price_filters] = params.select{|k, v| [:preis_von, :preis_bis].include?(k.to_sym) }

        per_page = params[:per_page].to_i
        @properties[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
        @properties[:page] = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
      end

    end
  end
end