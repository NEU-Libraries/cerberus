# frozen_string_literal: true

# Refuses to start a run that would touch the wrong Atlas, or that cannot
# authenticate to any Atlas at all.
#
# The suite opens with `AtlasRb::Reset.clean`, which wipes and reseeds whichever
# instance ATLAS_URL names. That endpoint authenticates *optionally* — it signs
# when a credential is available and sends no Authorization header otherwise —
# so it is the one call that still succeeds when the app has no credentials.
# A run whose ATLAS_URL resolved to a non-test instance therefore does not fail
# on the reset; it destroys that instance's data and carries on. Everything
# after it fails on auth, which reads as a hundred unrelated red examples and
# buries the one line that mattered.
#
# Both checks run before the reset, cost nothing, and name their own fix.
module SpecPreflight
  # config/environments/test.rb pins ATLAS_URL at the test instance. This
  # asserts that the pin survived environment loading and that nothing
  # reassigned it afterwards — an initializer, a dotenv file, or an inherited
  # value from the container when the run booted in the wrong RAILS_ENV.
  TEST_ATLAS_HOST = 'atlas-test'

  class UnsafeTarget < StandardError; end

  def self.assert_safe_to_reset!
    assert_test_atlas!
    assert_credentials!
    assert_reachable!
  end

  def self.assert_test_atlas!
    url = ENV.fetch('ATLAS_URL', nil)
    return if Rails.env.test? && url.to_s.include?(TEST_ATLAS_HOST)

    raise UnsafeTarget, <<~MSG
      Refusing to run: this suite resets the Atlas it points at, and it is not pointing at the test instance.

        RAILS_ENV   #{Rails.env}
        ATLAS_URL   #{url.inspect}
        expected    a URL containing "#{TEST_ATLAS_HOST}" (see config/environments/test.rb)

      Running now would wipe and reseed that instance. If this is a development
      Atlas, its objects would be re-minted with new NOIDs while Solr kept the
      old documents, leaving search results that all 404.
    MSG
  end

  # The test Atlas sits behind a compose profile, so a plain `up` does not start
  # it and it is legitimately absent much of the time. Without this the run dies
  # in AtlasRb::Reset on a name-resolution error from deep inside Faraday, which
  # reads like an outage rather than a container nobody asked for yet. A TCP
  # connect is enough to tell the two apart, and costs nothing when it succeeds.
  def self.assert_reachable!
    uri = URI.parse(ENV.fetch('ATLAS_URL'))
    Socket.tcp(uri.host, uri.port, connect_timeout: 2, &:close)
  rescue SocketError, SystemCallError
    raise UnsafeTarget, <<~MSG
      Refusing to run: nothing is listening on #{uri.host}:#{uri.port}, so there is no test Atlas to reset.

      It is behind the `atlas-test` compose profile and does not start with a plain
      `up`. The wrappers bring it up for you:

        bin/spec spec/models/my_spec.rb   # one process
        bin/parallel-spec                 # sharded across four

      Release it again with `bin/spec --down` or `bin/parallel-spec --down`.
    MSG
  end

  # A worktree created by `git worktree add` has no config/master.key: the key
  # is gitignored, so only tracked files come across. Every credential then
  # resolves nil, atlas_rb cannot sign an assertion, and Atlas rejects the
  # whole run. Caught here it is one line; caught by the suite it is hundreds
  # of failures that all look like an Atlas outage.
  def self.assert_credentials!
    return if Rails.application.credentials.cerberus_signing_key.present?

    raise UnsafeTarget, <<~MSG
      Refusing to run: credentials.cerberus_signing_key is nil, so atlas_rb cannot sign any request.

      Usually this is a worktree with no config/master.key. Copy it in — it is
      gitignored, so it will not stage:

        cp #{Rails.root.parent.join('cerberus/config/master.key')} #{Rails.root.join('config/master.key')}

      In CI, set RAILS_MASTER_KEY instead.
    MSG
  end
end
