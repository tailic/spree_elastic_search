//= require store/spree_frontend
//= require twitter/typeahead
//= require URI.min
//= require ion.rangeSlider.min

if (Spree === undefined) {
    var Spree = {}
    }
if (Spree.routes == undefined) {
    Spree.routes = {}
    }
if (Spree.api == undefined) {
    Spree.api = {}
}
// TODO Set this from config / env vars!!
Spree.routes.product_search = "http://meinwohnstore.dev/api/products";
var engine = new Bloodhound({
    limit: 10,
    datumTokenizer: function (d) {
        return Bloodhound.tokenizers.whitespace(d.value);
    },
    queryTokenizer: Bloodhound.tokenizers.whitespace,
    remote: {
        url: Spree.routes.product_search + '?token=%KEY&q=%QUERY&taxon=%TAXON&autocomplete=true&template=index_autocomplete',
        replace: function(url, query){
            return url.replace("%QUERY", query)
                        .replace("%TAXON", $("#search-select").val())
                        .replace("%KEY", Spree.api_key || "f993ba069ad462543f3d3f7741d5628c4557ade74644a592");
        },
        filter: function (data) {
            return $.map(data.products, function (product) {
                return {
                    //total_count: data.total_count,
                    value: product.name,
                    brand: product.manufacturer_name,
                    category: product.category_name,
                    link: product.permalink
                };
            });
        }
    }
});

var promise = engine.initialize();
promise
    .done(function() { })
    .fail(function() { });


$(function() {
    $('.typeahead').typeahead({
        hint: true,
        highlight: true,
        minLength: 2,
        rateLimitBy: 'debounce',
        rateLimitWait: 500
    }, {
        displayKey: 'value',
        source: engine.ttAdapter(),
        templates: {
            header: function(data) { return "<p class='tt-suggestion'>Vorschläge zu Ihrer Suche:</p>"; },
            suggestion: function(data){ return '<a href="/products/'+data.link+'">'+data.brand+' '+ data.category +' – '+data.value+'</a>'; }
        }
    });

    $("#price-range").ionRangeSlider({
        onFinish: function (data) {
            console.log(data)
            uri = URI(document.url)
                .setSearch("preis_von", data.from_value)
                .setSearch("preis_bis", data.to_value)
            document.location = uri;
        }
    });

    $("#sort").change(function(data) {
        console.log(data);
        uri = URI(document.url)
            .setSearch("sort", data.target.value)
        document.location = uri;
    })
});