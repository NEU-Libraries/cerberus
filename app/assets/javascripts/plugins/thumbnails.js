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
    var thumnailPlugin = "thumbmail",
        defaults = {
            target: $('img[data-thumbnail]')
        };

    // The actual plugin constructor
    function Plugin( element, options ) {
        this.element = element;
        var thumbnails = {},
        currentClass = this.$img.attr('class');

        this.options = $.extend( {}, defaults, options) ;

        this._defaults = defaults;
        this._name = thumnailPlugin;

        this.init();
    }



    /**
     * Thumbnail Class to handle changing source.
     * @param {DOM element} img image to initiate the the methods on.
     */
    var Thumbnail = function( ){
      
      
    
      this.getThumnbnailData(); 
    };

    Thumbnail.prototype.
      };
    /**
     * Method to change the source and classes.
     * @param  {string} classKey target class and for the image source to set.
     * @return {class property} 
     */
    Thumbnail.prototype = {
      var getThumnbnailData = function(){
        var thumbnails = this.$img.data('thumbnails');
        if (typeof thumbnails === 'undefined '){
          throw 'Invalid data for imgs';
        }else{
          return this.thumbnails = thumbnails;
        }
      
      if ( classKey === this.currentClass ){
        throw new Error('Current class matches the given classKey');
      }else if ( ! classKey in this.thumbnails ) {
        throw new Error('Invalid class key to change to');
      }else{
        this.$img.removeClass(this.currentClass)
          .addClass(classKey).attr('src', this.thumbnails[classKey]);
          this.currentClass = classKey;
      }
    };

    Plugin.prototype = {

        init: function() {
            
            
            
            
            
            
        },

        yourOtherFunction: function(el, options) {
            // some logic
        }
    };

    // A really lightweight plugin wrapper around the constructor,
    // preventing against multiple instantiations
    $.fn[pluginName] = function ( options ) {
        return this.each(function () {
            if (!$.data(this, "plugin_" + pluginName)) {
                $.data(this, "plugin_" + pluginName,
                new Plugin( this, options ));
            }
        });
    };

})( jQuery, window, document );