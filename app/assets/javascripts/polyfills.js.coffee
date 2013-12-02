Modernizr.load
  test: Modernizr.input.placeholder
  nope: ['/assets/polyfills/placeholder/placeholder.min.js']
  complete: -> 
    Placeholders.enable() if Placeholders?


Modernizr.load 
  test: Modernizr.mq('only all')
  nope: ['//cdnjs.cloudflare.com/ajax/libs/respond.js/1.3.0/respond.min.js'] 