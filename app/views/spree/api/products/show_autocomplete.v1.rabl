#object @result
#node(:name) { |result| result[1] }
#attributes :name, :description
# cache [current_currency, root_object]
# attributes *product_attributes
# node(:display_price) { |p| p.display_price.to_s }
# node(:brand) { |p| p.cached_manufacturer.name }
# node(:category) { |p| p.cached_category.name }
# child :variants_including_master => :variants do
#   attributes *variant_attributes
#
#   child :option_values => :option_values do
#     extends "spree/api/option_values/show"
#   end
#
#   child :images => :images do
#     extends "spree/api/images/show"
#   end
# end
#
# child :option_types => :option_types do
#   attributes *option_type_attributes
# end
#
# child :product_properties => :product_properties do
#   attributes *product_property_attributes
# end
