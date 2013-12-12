describe('Thumbnails should initialize an object', function(){
    beforeEach(function(){
      loadFixtures('drs-thumbnail-class.html'); 
      
      var thumbnail = $('.drs-item').first().find('img').thumbnail();
    });
    

    it('should be able to find its other sources indexed by naming convention', function(){
      console.log(thumbnail.element);

    });


});