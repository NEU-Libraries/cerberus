# Copyright © 2012 The Pennsylvania State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


module UsersHelper

  def display_user_name(recent_document)
    return "no display name" unless recent_document.depositor
    return User.find_by_user_key(recent_document.depositor).name rescue recent_document.depositor
  end

  def number_of_deposits(user)
    ActiveFedora::SolrService.query("#{Solrizer.solr_name('depositor', :stored_searchable, :type => :string)}:#{user.user_key}").count
  end

  def link_to_profile(login)
    user = User.find_by_user_key(login)
    return login if user.nil?

    text = if user.respond_to? :name
      user.name
    else
      login
    end

    link_to text, profile_path(user)
  end

end
