Modernizr.load
  test: Modernizr.mq('only all')
  nope: ['//cdnjs.cloudflare.com/ajax/libs/respond.js/1.3.0/respond.min.js']

$.webshims.setOptions( 'basePath', '/webshims/1.16.0/shims/' )
$.webshims.polyfill( 'forms es5 geolocation dom-support' )
