Modernizr.load
  test: Modernizr.input.placeholder
  nope: ['/assets/polyfills/placeholder/placeholder.min.js']
  complete: -> Placeholders.enable() if Placeholders?

Modernizr.load 
  test: Modernizr.mq('only all')
  nope: ['/assets/polyfills/respond/respond.min.js']
