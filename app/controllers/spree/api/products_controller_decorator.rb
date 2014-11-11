Spree::Api::ProductsController.class_eval do
  def index
    if params[:autocomplete]
      respond_with(autocomplete)
      return
    end

    if params[:ids]
      @products = product_scope.where(:id => params[:ids].split(","))
    else
      @products = Spree::Search::ElasticSearch.new({keywords: params[:q]}).retrieve_products.records
      #@products = product_scope.ransack(params[:q]).result
    end
    @products = @products.distinct.page(params[:page]).per(params[:per_page])
  end

  def autocomplete
      elasticsearch = Spree::Search::ElasticSearch.new({keywords: params[:q], taxon: params[:taxon]})
      @products = elasticsearch.results
  end
end


