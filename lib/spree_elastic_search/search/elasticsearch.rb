module Spree
  module Search
    class ElasticSearch
      attr_accessor :current_user
      attr_accessor :current_currency
      attr_accessor :params
      attr_accessor :property_params

      def initialize(params={})
        @params = params
        @page = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
        @property_params = parse_property_params

        taxon = params.fetch(:id, '')
        taxon_name = taxon.split('/').last
        #TODO need to force another taxon for autocompletion this is ugly
        taxon_name = Spree::Taxon.find(params[:taxon_force]).name if params[:taxon_force].present?
        options = {
            taxon_name: taxon_name || nil,
            properties: @property_params,
            limit: params[:limit],
            }.merge(params).with_indifferent_access
        @search_result = Spree::Product.elasticsearch(params[:keywords], options)
      end

      def results
        @search_result.results
      end

      def retrieve_products
        begin
          products = @search_result.page(@params[:page]).per(per_page)
          return [] if products.empty?
        rescue Faraday::TimeoutError => e
          return []
        rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
          return []
        end
        return products
      end

      def suggestions
        begin
          suggest = @search_result.response[:suggest]
        rescue Faraday::TimeoutError => e
          return []
        rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
          return []
        end
        return [] if suggest.nil?

        suggest.map do |k, v|
          v.collect{ |hashie| hashie.options }
        end.flatten
      end

      def aggregations
        @aggregations || begin
          aggs = results.response.response['aggregations'].reject{|k, v| k.eql? 'price_stats'}
          @aggregations = aggs.collect do |name, buckets|
            next if name.eql? 'price_stats'
            buckets = buckets.properties if name == 'properties'
            buckets = buckets.buckets.collect do |b|
              # key, val = b[:key].split('||') if name == 'properties'
              # key, val = [name, b[:key_as_string]] if b[:key_as_string]
              # {key: key, value: val, count: b.doc_count}
            end
            { name => buckets.group_by{|b| b[:key]} }
          end.reduce({}, :merge)
        end
      end

      def prices
        begin
          stats = results.response.response['aggregations']['price']['price'].buckets.collect{|p| p[:key]}
        rescue Faraday::TimeoutError => e
          return []
        rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
          return []
        end
        return stats
      end

      def lost_params
        @lost_params || begin
          choosen = property_params
          aggs = results.response.response['aggregations']
          available = aggs.reject{|k, v| ['price_stats', 'taxons'].include?(k) || !choosen.key?(k) }.collect do |a|
            {a[0] => a[1].send(a[0]).buckets.collect{|v| v[:key]}}
          end.compact.reduce( Hash.new, :merge)

          @lost_params = available.collect do |k, v|
            cleaned_values = choosen[k].reject {|c| v.include?(c) }
            {k => cleaned_values} if cleaned_values.present?
          end.compact.reduce( Hash.new, :merge).with_indifferent_access
        end
      end

      protected

      def per_page
        per_page = params[:per_page].to_i
        per_page > 0 ? per_page : Spree::Config[:products_per_page]
      end

      def parse_property_params
        @params.select{|k, v| Spree::Config.show_facets.keys.include? k.to_sym }
      end

    end
  end
end