module Spree
  module Search
    class ElasticSearch
      attr_accessor :current_user
      attr_accessor :current_currency
      attr_accessor :params

      def initialize(params={})
        @params = params
        @page = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
        taxon = params.fetch(:id, '')
        taxon_name = taxon.split('/')[1].try(:capitalize)
        options = {
            taxon_name: taxon_name || nil,
            properties: params[:properties],
            limit: params[:limit],
            }.merge(params).with_indifferent_access
        @search_result = Spree::Product.elasticsearch(params[:keywords], options)
      end

      def results
        @search_result.results
      end

      def retrieve_products
        @search_result.page(@params[:page]).per(per_page)
      end

      def suggestions
        suggest = @search_result.response[:suggest]
        return [] if suggest.nil?

        suggest.map do |k, v|
          v.collect{ |hashie| hashie.options }
        end.flatten
      end

      def aggregations
        @aggregations || begin
          aggs = @search_result.results.response.response['aggregations'].reject{|k, v| k.eql? 'price_stats'}
          @aggregations = aggs.collect do |name, buckets|
            next if name.eql? 'price_stats'
            buckets = buckets.buckets.collect do |b|
              key, val = b[:key].split('||')
              {key: key, value: val, count: b.doc_count}
            end
            { name => buckets.group_by{|b| b[:key]} }
          end.reduce({}, :merge)
        end
      end

      protected

      def per_page
        per_page = params[:per_page].to_i
        per_page > 0 ? per_page : Spree::Config[:products_per_page]
      end

    end
  end
end