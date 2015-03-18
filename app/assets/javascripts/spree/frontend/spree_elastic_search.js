//= require spree/frontend

if (Spree === undefined) {
    var Spree = {}
    }
if (Spree.routes == undefined) {
    Spree.routes = {}
    }
if (Spree.api == undefined) {
    Spree.api = {}
}

$(function() {
    $("#sort").change(function(data) {
        if(data.target.value){
            uri = URI(document.url).setSearch("sort", data.target.value);
            document.location = uri
        }
    })
});