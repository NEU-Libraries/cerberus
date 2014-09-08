class Ability
  include Hydra::Ability

  def custom_permissions
    all_types = [String, ActiveFedora::Base, SolrDocument]

    # Update read to always return true for users who are
    # proxy staff.  Doesn't bust up the rest of the read permissions logic/
    # require that we modify it in any way, which is pretty nice.
    can :read, all_types do |irrelevant|
      current_user.proxy_staff?
    end
  end
end

