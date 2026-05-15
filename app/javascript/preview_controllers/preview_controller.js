import ace from 'ace-builds';

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    ace.config.set('basePath', '/ace/');
    var editor = ace.edit("editor");
    editor.setTheme("ace/theme/eclipse");
    editor.session.setMode("ace/mode/xml");

    // Ace doesn't fire DOM `change` events on its container div; it has its
    // own event system. Listening on `#editor` never fires, leaving the
    // hidden field empty and the submit ships raw_xml="" — the validator
    // then correctly reports "Empty document."
    editor.session.on('change', () => {
      document.getElementById("raw_xml").value = editor.getSession().getValue().trim();
    });

    document.getElementById('validate_button').onclick = function(){
      $(".loading-state").css({visibility:"visible", opacity: 0.0}).animate({opacity: 1.0}, 500);
    };
  }
}
