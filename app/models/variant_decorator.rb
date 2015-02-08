Spree::Variant.class_eval do
  include Searchable

  scope :list, -> { joins(:prices, product: :option_types).where("spree_prices.amount > ? and (spree_option_types.presentation = ? or spree_variants.is_master = ?)", 0, "Farbe", true) }

  def taxons
    product.taxons
  end

  def content_per_package
    product.content_per_package
  end

  def cached_manufacturer
    product.cached_manufacturer
  end

  def variants
    []
  end

  def product_properties
    product.product_properties
  end

  def property(x)
    return option_values.first.presentation.split[0] if is_carpetfloor? && x == 'Farbe' && option_values.present?
    product.property(x)
  end

  def is_carpetfloor?
    product.is_carpetfloor?
  end

  def is_flooring?
    product.is_flooring?
  end

  def name
    return "#{product.name} #{option_values.first.presentation}" if is_carpetfloor? && option_values.present?
    product.name
  end

  def permalink
    variant_extension = option_values.first.present? ? "#/#{option_values.first.presentation.to_url}" : ''
    "#{product.permalink}#{variant_extension}"
  end

  def category_name
    product.category_name
  end

  def stars
    product.stars
  end

  def reviews_count
    product.reviews_count
  end

  #TODO refactor calculate on import > alternate prices gem now available!
  def price_per_unit(currency = Spree::Config[:currency])
    return Spree::Money.new(price_in(currency)) unless is_flooring? || is_carpetfloor?
    return Spree::Money.new(amount_in(currency, Spree::PriceCategory.find_by(name: 'glattschnitt'))) if is_carpetfloor?
    Spree::Money.new(price_in(currency).amount / content_per_package)
  end
end