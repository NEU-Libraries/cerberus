# frozen_string_literal: true

class BreadcrumbTrail < Croutons::BreadcrumbTrail
  def works_show
    # breadcrumb(objects[:work].parent.parent.title, project_path(objects[:work].parent.parent))
    # breadcrumb(objects[:work].parent.title, collection_path(objects[:work].parent))
    # breadcrumb(objects[:work].title)
  end
end
