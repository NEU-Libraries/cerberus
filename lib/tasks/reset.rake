require 'active_fedora/cleaner'

namespace :reset do
  task :fixtures => :environment do
    Rake::Task['reset:clean'].invoke or exit!(1)

    root_dept = Community.new(id: 'neu1', title: 'Northeastern University', description: "Founded in 1898, Northeastern is a global, experiential, research university built on a tradition of engagement with the world, creating a distinctive approach to education and research. The university offers a comprehensive range of undergraduate and graduate programs leading to degrees through the doctorate in nine colleges and schools, and select advanced degrees at graduate campuses in Charlotte, North Carolina, and Seattle.")
    root_dept.publicize
    root_dept.save!

    engDept = create_container(Community, 'neu1', 'English Department')
    sciDept = create_container(Community, 'neu1', 'Science Department')
    litCol = create_container(Collection, engDept.id, 'Literature')
    roCol = create_container(Collection, engDept.id, 'Random Objects')
    rusNovCol = create_container(Collection, litCol.id, 'Russian Novels')
  end
  task :clean => :environment do
    if Rails.env.development? || Rails.env.staging?
      begin
        ActiveFedora::Cleaner.clean!
      rescue Faraday::ConnectionFailed, RSolr::Error::ConnectionRefused => e
        $stderr.puts e.message
      end
    end
  end
end

def create_container(klass, parent_str, title_str, description = "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Recusandae, minima, cum sit iste at mollitia voluptatem error perspiciatis excepturi ut voluptatibus placeat esse architecto ea voluptate assumenda repudiandae quod commodi.")
  con = klass.new(parent: ActiveFedora::Base.find(parent_str), title: title_str, description: description)

  con.publicize!
  con.save!

  return con
end
