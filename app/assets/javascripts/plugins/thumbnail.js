/*!
 * jQuery lightweight plugin boilerplate
 * Original author: @ajpiano
 * Further changes, comments: @addyosmani
 * Licensed under the MIT license
 */

// the semi-colon before the function invocation is a safety
// net against concatenated scripts and/or other plugins
// that are not closed properly.
;(function ( $, window, document, undefined ) {


    // Create the defaults once
    var thumnailPlugin = "thumbnail",
        defaults = {
            
        };

    // The actual plugin constructor
    function Thumbnail( element, options ) {
        this.$element = $(element);
        var thumbnails = {},
        currentClass = $(this.element).attr('class');
        this.options = $.extend({}, defaults , options);
        if (this.options.parent) this.$parent = $(this.options.parent);
        this.settings = $.extend( {}, defaults, options) ;
            
        this._defaults = defaults;
        this._name = thumnailPlugin;

        this.init();
    }




    Thumbnail.prototype = {
      init: function() {
        this.getThumnbnailData();     
                
        this.parent = this.$element.closest('.drs-item');
        if(this.options.changeSrc){
          this.changeSrc(this.options.ChangeSrc)
        } 
          
        this.$element.css('background', 'red');
      },


      getThumnbnailData: function(){
        var thumbnails = this.$element.data('thumbnails');
        if (typeof thumbnails === 'undefined '){
          throw 'Invalid data for imgs';
        }else{
          return this.thumbnails = thumbnails;
        }
      },

      /**
       * Method to change the source and classes.
       * @param  {string} classKey target class and for the image source to set.
       * @return {class property} 
       */

      changeSrc: function(classKey){
        if ( classKey === this.currentClass ){
          throw new Error('Current class matches the given classKey');
        }else if ( ! classKey in this.thumbnails ) {
          throw new Error('Invalid class key to change to');
        }else{
          this.$element.removeClass(this.currentClass)
            .addClass(classKey).attr('src', this.thumbnails[classKey]);
            this.currentClass = classKey;
        }
      },


      
    };



    
    // A really lightweight plugin wrapper around the constructor,
    // preventing against multiple instantiations
    $.fn[ thumnailPlugin ] = function ( options ) {
      return this.each(function() {
        if ( !$.data( this, "plugin_" + thumnailPlugin ) ) {
          var $this   = $(this);
          var data    = $this.data('drs-thumbnails')

          
          $.data( this, "plugin_" + thumnailPlugin, new Thumbnail( this, options ) );
          if (typeof options == 'string'){
            data[options]();
          } 
        }
      });
    };





})( jQuery, window, document );