module NuCoreFileHelper
	def help_icon(key)
		link_to '#', id: "nu_core_file_#{key.to_s}_help", rel: 'popover', 
		  'data-content' => metadata_help(key),
		  'data-original-title' => get_label(key) do
		    content_tag 'i', '', class: "icon-question-sign icon-large"
		end
	end

	def render_edit_field_partial(key, locals)
		render_edit_field_partial_with_action('nu_core_files', key, locals)
	end

	def render_show_field_partial(key, locals)
		render_show_field_partial_with_action('nu_core_files', key, locals)
	end
end