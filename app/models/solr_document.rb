# -*- encoding : utf-8 -*-
class SolrDocument
  include Cerberus::SolrDocumentBehavior
  include Blacklight::Solr::Document

  SolrDocument.use_extension(BlacklightOaiProvider::SolrDocumentExtension)

  use_extension ( Blacklight::Solr::Document::Mods )

  def pf_belongs_to_user?(user)
    is_member_of = self.is_member_of
    cruft, slash, pid = is_member_of.rpartition('/')

    employee = Employee.find(pid)

    user ? user.nuid == employee.nuid : false
  end
end
