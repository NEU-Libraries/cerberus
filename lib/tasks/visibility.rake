# frozen_string_literal: true

namespace :visibility do
  desc 'Report resources more visible than the container they sit in'
  task audit: :environment do
    violations = VisibilityAudit.new.call

    if violations.empty?
      puts 'No containment violations found.'
      next
    end

    leaks = violations.select(&:public?)
    puts "#{violations.size} containment violation#{'s' unless violations.size == 1} found."
    # Called out separately because they are a different severity: a public
    # resource inside a restricted container is readable and downloadable by
    # anyone, while a group mismatch only means the audiences disagree.
    puts "#{leaks.size} of them are public inside a non-public container." if leaks.any?
    puts

    violations.each { |violation| puts "  #{violation}" }
    puts
    puts 'Nothing has been changed. Narrowing the child or widening the container is a'
    puts 'curation decision — the right answer depends on what the material is.'
  end
end
