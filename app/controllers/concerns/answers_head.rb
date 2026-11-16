# frozen_string_literal: true

# Rails answers HEAD by running the GET action and dropping the body, so the
# gates still decide the status. This skips building the body that would be
# dropped. See docs/head-requests.md.
module AnswersHead
  private

    # The template only: render_to_body still applies the status and content
    # type before it gets here, and JSON and plain renderers never reach it.
    def _render_template(options)
      return super unless request.head?

      self.content_type ||= Mime[lookup_context.formats.first].to_s
      ''
    end
end
