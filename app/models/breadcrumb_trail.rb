# frozen_string_literal: true

class BreadcrumbTrail < Croutons::BreadcrumbTrail
  def works_show
    breadcrumb_to_root(objects[:work]).each do |r|
      r.decorate
      breadcrumb(r.plain_title, polymorphic_path(r))
    end
  end

  private
    def breadcrumb_to_root(resource)
      trail = [resource]
      parent = resource.parent
      loop do
        if !parent.nil?
          trail << parent
          parent = parent.parent
        else
          return trail.reverse
        end
      end
    end
end
