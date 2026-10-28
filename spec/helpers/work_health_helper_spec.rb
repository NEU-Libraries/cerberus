# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkHealthHelper do
  def finding(code, severity: 'repairable')
    AtlasRb::Mash.new('code' => code, 'severity' => severity, 'subject' => 'w1', 'message' => 'm')
  end

  describe '#work_health_fixity' do
    def fixity(result: nil, last_checked_at: nil, objects: 3, never_checked: 0)
      AtlasRb::Mash.new('result' => result, 'last_checked_at' => last_checked_at,
                        'objects' => objects, 'never_checked' => never_checked)
    end

    it 'dates a Work whose every object passed' do
      expect(helper.work_health_fixity(fixity(result: 'pass', last_checked_at: '2026-10-20T03:12:00Z')))
        .to eq('Verified October 19, 2026, passed.')
    end

    # A fail outranks a partial sweep: the Work is already graded red for it.
    it 'reports a fail even while some objects are unchecked' do
      expect(helper.work_health_fixity(fixity(result: 'fail', never_checked: 1)))
        .to start_with('Failed.')
    end

    it 'counts the objects a partial sweep has not reached' do
      expect(helper.work_health_fixity(fixity(result: 'pass', never_checked: 2)))
        .to eq('Partly verified: 2 of 3 files not yet checked.')
    end

    it 'says nothing is checked when nothing is recorded' do
      expect(helper.work_health_fixity(fixity(never_checked: 3))).to eq('Not yet checked.')
    end

    # An Atlas that predates the checker sends no block at all.
    it 'treats a missing block as never checked' do
      expect(helper.work_health_fixity({})).to eq('Not yet checked.')
    end
  end

  describe '#work_health_repair' do
    # Atlas adds codes as it adds checks, ahead of Cerberus.
    it 'gives an unknown code no link and no error' do
      html = helper.work_health_repair(finding('brand_new_check'), 'w1')

      expect(html).not_to include('<a', '<form')
      expect(html).to include('—')
    end

    it 'switches the pane in place on the tab' do
      html = helper.work_health_repair(finding('orphaned'), 'w1')

      expect(html).to include('href="#move"', 'Open the Move tab')
    end

    it 'opens the edit page tab from the admin lookup' do
      html = helper.work_health_repair(finding('orphaned'), 'w1', standalone: true)

      expect(html).to include(CGI.escapeHTML(edit_work_path('w1', tab: 'move')))
    end

    it 'sends every MODS code to the XML editor, out of the frame' do
      %w[mods_access_copy_missing descriptive_file_set_missing mods_xml_missing].each do |code|
        html = helper.work_health_repair(finding(code), 'w1')

        expect(html).to include(xml_editor_path('w1'), 'data-turbo-frame="_top"')
      end
    end

    it 'offers Reindex for a missing Solr document, returning to the Health tab' do
      html = helper.work_health_repair(finding('not_indexed'), 'w1')

      expect(html).to include(admin_reindex_work_path('w1'), CGI.escapeHTML(edit_work_path('w1', tab: 'health')))
    end
  end

  describe '#work_health_problems' do
    it 'orders fatal before repairable, leaves advisories out, and keeps an unknown severity last' do
      findings = [finding('a', severity: 'repairable'), finding('b', severity: 'advisory'),
                  finding('c', severity: 'novel'), finding('d', severity: 'fatal')]

      expect(helper.work_health_problems(findings).pluck('code')).to eq(%w[d a c])
    end
  end

  describe '#work_health_repair_offered?' do
    it 'is true only for a code this page can repair' do
      expect(helper.work_health_repair_offered?(finding('untitled'))).to be true
      expect(helper.work_health_repair_offered?(finding('not_indexed'))).to be true
      expect(helper.work_health_repair_offered?(finding('envelope_stale'))).to be false
    end
  end

  describe '#work_health_grade_label' do
    it 'names a grade it does not know rather than leaving the chip blank' do
      expect(helper.work_health_grade_label('green')).to eq('Green: viable')
      expect(helper.work_health_grade_label('purple')).to eq('Purple')
      expect(helper.work_health_grade_label(nil)).to eq('Ungraded')
    end
  end

  describe '#work_health_subject' do
    it 'calls the Work itself "this Work" and shows any other NOID' do
      expect(helper.work_health_subject('w1', 'w1')).to eq('this Work')
      expect(helper.work_health_subject('b9', 'w1')).to include('b9')
    end
  end
end
