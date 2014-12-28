# Indexer class for <http://sidekiq.org> taken from elasticsearch-rails Templates
#
# Run me with:
#
#     $ bundle exec sidekiq --queue elasticsearch --verbose
#
class Indexer
  include Sidekiq::Worker
  sidekiq_options queue: 'elasticsearch', retry: false, backtrace: true

  logger = Sidekiq.logger.level == Logger::DEBUG ? Sidekiq.logger : nil
  config = {
      host: 'http://localhost:9200/',
      transport_options: { request: { timeout: 5 } },
      logger: logger
  }

  if File.exists?('config/elasticsearch.yml')
    config.merge!(YAML.load_file('config/elasticsearch.yml').symbolize_keys)
  end

  Elasticsearch::Model.client = Elasticsearch::Client.new(config)
  Client = Elasticsearch::Client.new config

  def perform(operation, klass, record_id, options={})
    logger.debug [operation, "#{klass}##{record_id} #{options.inspect}"]

    case operation.to_s
      when /index|update/
        record = klass.constantize.find(record_id)
        record.__elasticsearch__.client = Client
        record.__elasticsearch__.__send__ "#{operation}_document"
      when /delete/
        Client.delete index: klass.constantize.index_name, type: klass.constantize.document_type, id: record_id
      else raise ArgumentError, "Unknown operation '#{operation}'"
    end
  end
end
