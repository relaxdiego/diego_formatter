$(document).ready(function(){
  $("a[rel]").overlay();
});

// get querystring as an array split on "&"
var querystring = location.search.replace( '?', '' ).split( '&' );

// declare object
var params = {};

// loop through each name-value pair and populate object
for ( var i=0; i<querystring.length; i++ ) {
      // get name and value
      var name = querystring[i].split('=')[0];
      var value = querystring[i].split('=')[1];
      // populate object
      params[name] = value;
}