xml.instruct! :xml, :version=>"1.0"
xml.rss(:version=>"2.0") {

  xml.channel {

    xml.title(application_name + " Search Results")
    xml.link("#{request.base_url}" + url_for(params))
    xml.description(application_name + " Search Results")
    xml.language('en-us')
    @document_list.each do |doc|
      xml.item do
        xml.title( doc.to_semantic_values[:title][0] || doc.title || doc.id )
        xml.link( doc.identifier || polymorphic_url(doc) )
        xml.description ( doc.description )
        xml.author( doc.to_semantic_values[:author][0] || doc.creator_list.join(";") )
      end
    end

  }
}
