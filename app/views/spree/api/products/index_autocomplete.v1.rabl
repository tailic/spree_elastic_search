object false
node(:count) { @products.count }
node(:total_count) { @products.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:per_page) { params[:per_page] || Kaminari.config.default_per_page }
node(:pages) { @products.num_pages }
node(:products) do
  @products.results.map do |p|
    #TODO Reduce information to minimum needed by search suggest
    p._source
    #partial("spree/api/products/show_autocomplete", object: p)
  end
end

# note(:suggestions) do
#   @products.
# end

# child(@products.results => :products) do
#   extends "spree/api/products/show_autocomplete"
# end