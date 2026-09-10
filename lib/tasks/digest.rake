# frozen_string_literal: true

namespace :admin do
  desc 'Write the admin ledger digest for a day (default: yesterday). rake admin:digest[2026-08-08]'
  task :digest, [:day] => :environment do |_task, args|
    day = args[:day].present? ? Date.parse(args[:day]) : Date.yesterday
    notice = DailyDigestJob.perform_now(day)

    if notice.nil?
      existing = AdminNotice.exists?(kind: AdminNotice::DIGEST, occurred_on: day)
      puts existing ? "#{day} already has a digest. Nothing written." : "Nothing happened on #{day}. No digest written."
      next
    end

    counts = notice.detail('counts') || {}
    puts "Digest written for #{day}."
    counts.each { |label, value| puts format('  %-22<label>s %<value>s', label: label, value: value) }
  end
end
