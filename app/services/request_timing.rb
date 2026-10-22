# frozen_string_literal: true

# One request's Atlas calls, collected from every thread the request uses, for
# the page response times on the admin health page. See docs/outages.md.
class RequestTiming
  def initialize
    @lock = Mutex.new
    @first_start_ms = nil
    @last_finish_ms = nil
    @calls = 0
  end

  # Monotonic milliseconds, which every thread in the process shares.
  def add_atlas_call(start_ms, finish_ms)
    @lock.synchronize do
      @calls += 1
      @first_start_ms = [@first_start_ms, start_ms].compact.min
      @last_finish_ms = [@last_finish_ms, finish_ms].compact.max
    end
  end

  def atlas_calls = @lock.synchronize { @calls }

  # From the start of the first call to the end of the last, so calls that ran
  # side by side count once, as the person waiting experienced them.
  def atlas_elapsed_ms
    @lock.synchronize { @calls.zero? ? 0.0 : @last_finish_ms - @first_start_ms }
  end
end
