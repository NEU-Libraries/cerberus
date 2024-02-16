import ace from 'ace-builds';

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    ace.config.set('basePath', 'https://cdn.jsdelivr.net/npm/ace-builds@1.16.0/src-noconflict/');
    var editor = ace.edit("editor");
    editor.setTheme("ace/theme/eclipse");
    editor.session.setMode("ace/mode/xml");

    document.querySelector('#editor').addEventListener('change', (event) => {
      //$("#raw_xml").val(editor.getSession().getValue().trim());
      document.getElementById("raw_xml").value = editor.getSession().getValue().trim();
    });

    document.getElementById('validate_button').onclick = function(){
      $(".loading-state").css({visibility:"visible", opacity: 0.0}).animate({opacity: 1.0}, 500);
    };
  }
}
