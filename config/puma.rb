# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
#
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Workers are forked processes, and processes are the only way a Ruby web server
# gets real parallelism: the GVL serialises Ruby execution within one process, so
# threads overlap only where a request waits on IO. Rendering a Blacklight page
# does not wait on IO, so concurrent users queue behind each other in single
# mode. Measured with four concurrent page loads, four workers took /catalog from
# 328ms to 132ms and a Work show page from 404ms to 182ms.
#
# This does almost nothing for one user on an idle box — a lone Work show page
# moved 129ms to 117ms — so read it as capacity, not latency.
#
# Atlas needs the same setting for the Work show page to benefit, because each
# page fans out into several Atlas reads and a single-mode Atlas re-serialises
# them. Cerberus workers alone recover 15% of that page; both together recover
# 51%. Atlas reads the same WEB_CONCURRENCY in its own config/puma.rb.
#
# Defaulting to 0 keeps single mode wherever it is not asked for, so development
# and the test suite are untouched.
web_concurrency = ENV.fetch("WEB_CONCURRENCY", 0).to_i
workers web_concurrency

# Boot the app before forking so workers share pages by copy-on-write. Puma 8
# preloads by default in cluster mode; saying so keeps the file honest about
# what happens, and survives a downgrade.
preload_app! if web_concurrency.positive?

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
