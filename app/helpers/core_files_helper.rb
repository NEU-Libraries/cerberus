module CoreFilesHelper
	def help_icon(key)
		link_to '#', id: "core_file_#{key.to_s}_help", rel: 'popover',
		  'data-content' => metadata_help(key),
		  'data-original-title' => get_label(key) do
		    content_tag 'i', '', class: "icon-question-sign icon-large"
		end
	end

	def render_edit_field_partial(key, locals)
		render_edit_field_partial_with_action('core_files', key, locals)
	end

	def render_show_field_partial(key, locals)
		render_show_field_partial_with_action('core_files', key, locals)
	end

	# Render a button for attaching files to this core_file
	# if the current user is admin.
	def render_attach_files_button(parent, text = "Attach files to this file" , html_options = {} )
		if (!current_user.nil? && ( current_user.admin_group? || current_user.admin? )) && !@core_file.has_master_object?
			link_to( text , new_attached_file_path, html_options )
		end
	end
end
