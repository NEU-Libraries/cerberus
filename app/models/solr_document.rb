# -*- encoding : utf-8 -*-
class SolrDocument
  # Adds Sufia behaviors to the SolrDocument.
  include Cerberus::SolrDocumentBehavior
  include Blacklight::Solr::Document

  # self.unique_key = 'id'

  # The following shows how to setup this blacklight document to display marc documents
  extension_parameters[:marc_source_field] = :marc_display
  extension_parameters[:marc_format_type] = :marcxml
  use_extension( Blacklight::Solr::Document::Marc) do |document|
    document.key?( :marc_display  )
  end

  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension( Blacklight::Solr::Document::Email )

  # SMS uses the semantic field mappings below to generate the body of an SMS email.
  SolrDocument.use_extension( Blacklight::Solr::Document::Sms )

  SolrDocument.use_extension(BlacklightOaiProvider::SolrDocumentExtension)

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Solr::Document::ExtendableClassMethods#field_semantics
  # and Blacklight::Solr::Document#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  # use_extension( Blacklight::Solr::Document::DublinCore)
  # field_semantics.merge!(
  #                        :title => "title_tesim"
  #                        )

  use_extension ( Blacklight::Solr::Document::Mods )

  def pf_belongs_to_user?(user)
    is_member_of = self.is_member_of
    cruft, slash, pid = is_member_of.rpartition('/')

    employee = Employee.find(pid)

    user ? user.nuid == employee.nuid : false
  end
end
