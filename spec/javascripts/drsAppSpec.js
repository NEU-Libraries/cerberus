describe('The drsApp global functions using the applications global functions', function() {
  
  describe('a user interaction that has a span apply a class to the target object on click ', function(){

    it('should apply a class on click and toggle the class of the icon-font with the link' , function() {
      
      
      var fixtures = loadFixtures('drsApp-ellipsis.html');
      $('#jasmine-fixtures').ready(function(){
        drsApp.init();
        console.log('drsApp inited');
          var icon = $('i');
          var link = $('#abstract5Toggle');
          expect(icon).toHaveClass('icon-expand-alt');

          $(link).trigger('click');
        
          expect(icon).toHaveClass('icon-collapse-alt');
      });
      
      
    });
  
  });
  


});