require 'elasticsearch/model'

Spree::Config.searcher_class = Spree::Search::ElasticSearch

# Connect to specific Elasticsearch cluster
ELASTICSEARCH_URL = ENV['ELASTICSEARCH_URL'] || 'http://localhost:9200'
Elasticsearch::Model.client = Elasticsearch::Client.new host: ELASTICSEARCH_URL, transport_options: { request: { timeout: 1 } }
# Print Curl-formatted traces in development into a file
#
if Rails.env.development?
  tracer = ActiveSupport::Logger.new('log/elasticsearch.log')
  tracer.level = Logger::DEBUG
end
Elasticsearch::Model.client.transport.tracer = tracer

Spree::Api::BaseController.class_eval do
  prepend_view_path File.expand_path("../../app/views", File.dirname(__FILE__))
end