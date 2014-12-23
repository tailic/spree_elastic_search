# Indexer class for <http://sidekiq.org> taken from elasticsearch-rails Templates
#
# Run me with:
#
#     $ bundle exec sidekiq --queue elasticsearch --verbose
#
class Indexer
  include Sidekiq::Worker
  sidekiq_options queue: 'elasticsearch', retry: false, backtrace: true

  es_url = 'http://10.15.186.16:9200' if Rails.env.production?
  es_url = 'http://10.8.82.14:9200' if Rails.env.staging?
  es_url = 'http://localhost:9200' if Rails.env.development?
  Logger = Sidekiq.logger.level == Logger::DEBUG ? Sidekiq.logger : nil
  Client = Elasticsearch::Client.new host: (es_url), logger: Logger

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
