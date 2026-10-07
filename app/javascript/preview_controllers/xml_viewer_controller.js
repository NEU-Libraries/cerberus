import ace from 'ace-builds';

import { Controller } from '@hotwired/stimulus'

// A read-only view of an XML document in the XML editor's own Ace panel: same
// theme and mode, so staff scan MODS the way they read it in the editor. The
// element holds a plain <pre> of the XML, which stays as the fallback if this
// never connects; on connect the XML moves into Ace and the <pre> goes.
export default class extends Controller {
  static targets = ['source']

  connect() {
    ace.config.set('basePath', '/ace/');
    const xml = this.sourceTarget.textContent;
    this.sourceTarget.remove();

    this.editor = ace.edit(this.element, {
      mode: 'ace/mode/xml',
      theme: 'ace/theme/eclipse',
      value: xml,
      readOnly: true,
      highlightActiveLine: false,
      highlightGutterLine: false,
      showPrintMargin: false,
    });
    this.editor.clearSelection();
    // Ace's hidden textarea is what a screen reader lands on, so it carries the name.
    this.editor.textInput.getElement().setAttribute('aria-label', 'MODS XML preview');
    // Read-only still draws a blinking cursor, which reads as "you can type here".
    this.editor.renderer.$cursorLayer.element.style.display = 'none';
  }

  disconnect() {
    this.editor?.destroy();
  }
}
