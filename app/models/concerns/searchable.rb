module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    # Customize the index name
    #
    index_name [Rails.application.engine_name, Rails.env].join('_')

    filter = {
        name_ngrams: {
            min_gram: 3,
            max_gram: 6,
            type: 'edgeNGram'
        }
    }

    analyzer = {
        partial_name: {
            filter: %w(standard lowercase name_ngrams),
            type: 'custom',
            tokenizer: 'standard',
            tokenizer: 'whitespace'
        }
    }
    # Set up index configuration and mapping
    #
    settings index: {number_of_shards: 1, number_of_replicas: 0}, analysis: {filter: filter, analyzer: analyzer} do
      mapping do
        indexes :name, type: 'multi_field' do
          indexes :name, analyzer: 'snowball'
          indexes :tokenized, analyzer: 'simple'
          indexes :namengram, analyzer: 'partial_name'
        end

        indexes :meta_description, type: 'multi_field' do
          indexes :meta_description, analyzer: 'snowball'
          indexes :tokenized, analyzer: 'simple'
          indexes :ngram, analyzer: 'partial_name'
        end

        indexes :price_per, type: 'double'

        indexes :description, type: 'multi_field' do
          indexes :description, analyzer: 'snowball'
          indexes :tokenized, analyzer: 'simple'
        end

        indexes :taxon_ids, analyzer: 'keyword'
        indexes :taxon_names, analyzer: 'keyword'

        indexes :properties, type: 'multi_field' do
          indexes :properties, analyzer: 'keyword'
        end

        indexes :property, type: 'multi_field' do
          indexes :property, analyzer: 'keyword'
          indexes :tokenized, analyzer: 'simple'
        end

      end
    end

    # Set up callbacks for updating the index on model changes
    #
    after_commit lambda { Indexer.perform_async(:index, self.class.to_s, self.id) }, on: :create
    after_commit lambda { Indexer.perform_async(:update, self.class.to_s, self.id) }, on: :update
    after_commit lambda { Indexer.perform_async(:delete, self.class.to_s, self.id) }, on: :destroy
    after_touch lambda { Indexer.perform_async(:update, self.class.to_s, self.id) }

    def list_image(style = :list)
      #TODO Advanced image search in variants
      return "noimage/#{style.to_s}.png" if images.empty?
      images.first.attachment(style)
    end

    def taxon_names
      taxons.collect(&:name)
    end

    def price_per
      price_per_unit.money.to_f
    end

    def as_indexed_json(options={})
      hash = as_json({
                         methods: [:id, :name, :meta_name, :category_name, :manufacturer_name, :permalink,
                                   :meta_description, :description, :taxon_ids, :taxon_names, :list_image, :price_per, :price_per_unit, :stars],
                         include: {
                             cached_manufacturer: { only: [:id, :taxonomy_id, :visible, :permalink, :name]},
                             variants: {
                                 only: [:sku],
                                 include: {
                                     option_values: {only: [:name, :presentation]}
                                 }
                             }
                         }
                     })
      hash['properties'] = product_properties.map do |pp|
        [pp.property.name, pp.value].join('||') if Spree::Config.show_facets.include?(pp.property.name)
      end

      hash['property'] = product_properties.map { |pp| [pp.property.name, pp.value].join(' ') }
      hash

    end

    # Search in title and content fields for `query`, include highlights in response
    #
    # @param query [String] The user query
    # @return [Elasticsearch::Model::Response::Response]
    #
    def self.elasticsearch(query, options={})
      @search_definition = {
          query: {},

          aggs: {
              taxons: {
                  terms: { field: 'taxon_names', size: 0 }
              },
              properties: {
                  terms: { field: 'properties', size: 0, min_doc_count: 0, order: { _term: 'asc' }
      }
              },
              price_stats: {
                  stats: { field: 'price_per' }
              }
          }
      }


      unless query.blank?
        @search_definition[:query] = {
            filtered: {
                query: {
                    bool: {
                        should: [
                            {
                                multi_match: {
                                    query: query,
                                    minimum_should_match: '65%',
                                    fields: ['meta_description.ngram', 'description', 'property'],
                                    type: 'cross_fields',
                                    #operator: 'and'
                                }
                            }
                        ]
                    }
                },
              filter: {}
            }
        }
      else
        @search_definition[:query] = { filtered: { filter: { bool: { must: [] }} } }
        @search_definition[:post_filter] = { bool: { must: [] } }
        #@search_definition[:sort] = {name: 'asc'}
      end

      if options[:taxon_name] && options[:taxon_name].present?
        f = {term: {taxon_names: [options[:taxon_name]]}}
        @search_definition[:query][:filtered][:filter][:bool][:must] << f
      end

      if options[:properties]
        options[:properties].each do |prop|
          f= {terms: {properties: prop}}
          @search_definition[:query][:filtered][:filter][:bool][:must] << f
        end
      end

      if options[:preis_von] || options[:preis_bis]
        f = {
            range: {
                price_per: {
                    gte: options[:preis_von].to_f || 0.0,
                    lte: options[:preis_bis].to_f || 9999999999.0
                }
            }
        }
        #@search_definition[:query][:filtered][:filter][:bool][:must] << f
        #@search_definition[:post_filter].merge! f
        @search_definition[:post_filter][:bool][:must] << f
      end


      if options[:sort]
        if options[:sort][0, 2] == 'a_'
          order = 'asc'
          sort = options[:sort].gsub /^a_/, ''
        else
          order = 'desc'
          sort = options[:sort]
        end
        @search_definition[:sort] = {sort.strip => order}
        @search_definition[:track_scores] = true
      else
        @search_definition[:sort] = {name: 'asc'}
      end

      unless query.blank?
        @search_definition[:suggest] = {
            text: query,
            suggest_name: {
                term: {
                    field: 'name.tokenized',
                    suggest_mode: 'missing'
                }
            },
            suggest_description: {
                term: {
                    field: 'description.tokenized',
                    suggest_mode: 'missing'
                }
            }
        }
      end
Rails.logger.debug ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#{@search_definition.to_json}"

      __elasticsearch__.search(@search_definition)
    end
  end
end