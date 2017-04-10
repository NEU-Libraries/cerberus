class CommunityMemberSearchBuilder < ::SearchBuilder

  class_attribute :community_membership_field
  self.community_membership_field = 'isPartOf_ssim'

  # Defines which search_params_logic should be used when searching for community members
  self.default_processor_chain += [:member_of_community]

  delegate :community, to: :scope

  # include filters into the query to only include the community memebers
  def member_of_community(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "#{community_membership_field}:\"#{blacklight_params[:community]}\""
  end

end
