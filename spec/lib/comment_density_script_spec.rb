# frozen_string_literal: true

require 'rails_helper'
require 'open3'

# bin/comment-density inside `web`, run from a worktree, cannot reach git: the
# worktree's .git names a host path the container does not mount. A git failure
# must never read as "no files, all clean". GIT_DIR pointed at nothing stands in
# for that here.
RSpec.describe 'bin/comment-density' do
  let(:script) { Rails.root.join('bin/comment-density').to_s }
  let(:no_git) { { 'GIT_DIR' => '/nonexistent/git-dir' } }

  def run(*args, env: {}) = Open3.capture3(env, script, *args, chdir: Rails.root.to_s)

  # Naming every file needs no git, so it is the answer whether or not this
  # spec itself can reach git.
  it 'checks every file under app/ without git' do
    every_file, = run(*Dir.glob('app/**/*.rb', base: Rails.root.to_s).sort)
    without_git, _err, status = run(env: no_git)

    expect(status).to be_success
    expect(without_git).to eq every_file
  end

  it 'refuses --staged without git, rather than passing silently' do
    _out, err, status = run('--staged', env: no_git)

    expect(status.exitstatus).to eq 1
    expect(err).to include '--staged needs git'
  end
end
