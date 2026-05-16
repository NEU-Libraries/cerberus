import ace from 'ace-builds';

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    ace.config.set('basePath', '/ace/');
    var editor = ace.edit("editor");
    editor.setTheme("ace/theme/eclipse");
    editor.session.setMode("ace/mode/xml");

    // Sync the editor's current content into the hidden raw_xml field at
    // form-submit time. Single source of truth — doesn't matter whether
    // the user typed, undid, or just clicked Validate without touching
    // the editor; the hidden field always reflects what's in the editor
    // at the moment the form submits.
    const form = document.getElementById('raw_xml_form');
    if (form) {
      form.addEventListener('submit', () => {
        document.getElementById("raw_xml").value = editor.getSession().getValue().trim();
      });
    }

    // Fade the loading-state spinner in when Validate is clicked. The
    // turbo_stream response template handles fading it back out.
    const validateBtn = document.getElementById('validate_button');
    if (validateBtn) {
      validateBtn.addEventListener('click', () => {
        document.querySelectorAll(".loading-state").forEach((el) => {
          el.style.visibility = "visible";
          el.style.opacity = "0";
          el.style.transition = "opacity 500ms";
          requestAnimationFrame(() => { el.style.opacity = "1"; });
        });
      });
    }
  }
}
