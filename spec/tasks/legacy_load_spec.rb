# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'legacy:load' do
  let(:csv) { Tempfile.new(['legacy-map', '.csv']) }

  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'legacy:load' }
  end

  before { Rake::Task['legacy:load'].reenable }

  after { csv.close! }

  def write_csv(*rows)
    csv.write("pid,noid,object_type\n#{rows.join("\n")}\n")
    csv.flush
  end

  # Runs the task the way a caller sees it: its output, and the status it
  # exits with (nil when it returns normally).
  def load_map
    status = nil
    output = capture_stdout do
      Rake::Task['legacy:load'].invoke(csv.path)
    rescue SystemExit => e
      status = e.status
    end
    Rake::Task['legacy:load'].reenable
    [output, status]
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it 'writes every row of a clean CSV and returns normally' do
    write_csv('neu:1,abc1234,work', 'neu:2,def5678,collection')

    output, status = load_map

    expect(status).to be_nil
    expect(output).to include('Wrote 2 mappings.')
    expect(LegacyIdentifier.for_pid('neu:1').noid).to eq('abc1234')
    expect(LegacyIdentifier.for_pid('neu:2').object_type).to eq('collection')
  end

  it 'keeps the good rows, names the bad line, and exits 1' do
    write_csv('neu:1,abc1234,work', 'neu:2,def5678,folder', 'neu:3,ghi9012,community')

    output, status = load_map

    expect(status).to eq(1)
    expect(output).to include('Wrote 2 mappings.', 'Skipped 1:', 'line 3 (neu:2)')
    expect(LegacyIdentifier.where(pid: %w[neu:1 neu:3]).count).to eq(2)
    expect(LegacyIdentifier.for_pid('neu:2')).to be_nil
  end

  it 'adds no rows when the same CSV is loaded again' do
    write_csv('neu:1,abc1234,work', 'neu:2,def5678,collection')

    load_map
    expect { load_map }.not_to change(LegacyIdentifier, :count)
  end

  it 'keeps the last row when one CSV names a pid twice' do
    write_csv('neu:1,abc1234,work', 'neu:1,zzz9999,download')

    _output, status = load_map

    expect(status).to be_nil
    record = LegacyIdentifier.for_pid('neu:1')
    expect([record.noid, record.object_type]).to eq(%w[zzz9999 download])
    expect(LegacyIdentifier.where(pid: 'neu:1').count).to eq(1)
  end
end
