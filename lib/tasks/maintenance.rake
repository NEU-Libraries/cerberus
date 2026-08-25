# frozen_string_literal: true

# The read-only maintenance window, from the command line.
#
# Atlas holds the flag; these tasks are two of the three doors onto it. The
# third is the admin hub. Cerberus carries a copy of the open/close pair rather
# than sending everyone to Atlas's own task because the queues are Cerberus's
# to pause, and a window without a drain is not a window — a job already
# claimed keeps writing into whatever the migration is doing.
#
# SOURCE names the door. `deploy` exists so the orchestrator's close cannot end
# a window a person opened by hand: Atlas refuses that combination and answers
# with the unchanged state, which `close` reports rather than swallowing.
namespace :maintenance do
  desc 'Make the repository read-only. Usage: rake maintenance:open [MESSAGE=…] [RETRY_AFTER=…] [SOURCE=operator|deploy]'
  task open: :environment do
    window = MaintenanceMode.open!(
      message:     ENV.fetch('MESSAGE', nil).presence,
      retry_after: ENV.fetch('RETRY_AFTER', nil).presence&.to_i,
      source:      ENV.fetch('SOURCE', 'operator')
    )
    abort('Atlas did not open the window.') if window.read_only.blank?

    puts "The repository is read-only (source: #{window.source})."
  end

  desc 'Let the repository take writes again. Usage: rake maintenance:close [SOURCE=operator|deploy]'
  task close: :environment do
    source = ENV.fetch('SOURCE', 'operator')
    window = MaintenanceMode.close!(source: source)

    # A refused deploy-close is a 200 carrying the unchanged state, not an
    # error, so the only way to know is to read the flag back.
    if window.read_only.present?
      abort("The window is still open (opened by #{window.source}); a #{source} close cannot clear it.")
    end

    puts 'The repository is accepting writes again.'
  end

  desc 'Report the window without changing it'
  task status: :environment do
    window = MaintenanceMode.window
    if window.read_only.present?
      puts "Read-only since #{window.since || 'an unrecorded time'} (source: #{window.source || 'unknown'})."
      puts "Message: #{window.message}" if window.message.present?
    else
      puts 'Accepting writes.'
    end
  end

  desc 'Stop the queues taking new work (running jobs are left to finish)'
  task pause_queues: :environment do
    SolidQueue::Queue.all.each do |queue|
      queue.pause
      puts "Paused #{queue.name} (#{queue.size} waiting)."
    end
  end

  desc 'Let the queues take work again'
  task resume_queues: :environment do
    SolidQueue::Pause.find_each do |pause|
      # Solid Queue's own class-level finder on a plain Ruby class, not an
      # Active Record dynamic finder — it builds a Queue for the name.
      SolidQueue::Queue.find_by_name(pause.queue_name).resume # rubocop:disable Rails/DynamicFindBy
      puts "Resumed #{pause.queue_name}."
    end
  end

  desc 'Wait for in-flight jobs to finish. Usage: rake maintenance:drain [TIMEOUT=120]'
  task drain: :environment do
    timeout  = ENV.fetch('TIMEOUT', '120').to_i
    deadline = Time.current + timeout

    # Claimed executions are the jobs actually running. Ready ones are left
    # alone deliberately: the queues are paused, so they will not start, and
    # waiting for the ready set to empty would mean waiting for the whole
    # backlog rather than for the window to be safe.
    while (running = SolidQueue::ClaimedExecution.count).positive?
      if Time.current > deadline
        abort("#{running} job(s) still running after #{timeout}s. Investigate before migrating.")
      end

      puts "Waiting for #{running} running job(s)…"
      sleep 2
    end

    puts 'No jobs are running.'
  end

  desc 'Open the window and drain the queues, ready for a migration'
  task begin_window: :environment do
    Rake::Task['maintenance:open'].invoke
    Rake::Task['maintenance:pause_queues'].invoke
    Rake::Task['maintenance:drain'].invoke
  end

  desc 'Resume the queues and close the window'
  task end_window: :environment do
    Rake::Task['maintenance:resume_queues'].invoke
    Rake::Task['maintenance:close'].invoke
  end
end
