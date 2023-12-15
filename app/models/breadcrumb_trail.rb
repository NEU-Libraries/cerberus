# frozen_string_literal: true

class BreadcrumbTrail < Croutons::BreadcrumbTrail
  def works_show
    objects[:work]['ancestors'].each do |r|
      breadcrumb(AtlasRb.const_get(r[1]).find(r[0])['title'], public_send("#{r[1].downcase}_path", r[0]))
    end
    breadcrumb(objects[:work]['title'])
  end

  def collections_show
    objects[:collection]['ancestors'].each do |r|
      breadcrumb(AtlasRb.const_get(r[1]).find(r[0])['title'], public_send("#{r[1].downcase}_path", r[0]))
    end
    breadcrumb(objects[:collection]['title'])
  end

  def communities_show
    objects[:community]['ancestors'].each do |r|
      breadcrumb(AtlasRb.const_get(r[1]).find(r[0])['title'], public_send("#{r[1].downcase}_path", r[0]))
    end
    breadcrumb(objects[:community]['title'])
  end
end
