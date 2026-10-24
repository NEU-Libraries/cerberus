# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkHealthHelper do
  def finding(code, severity: 'repairable')
    AtlasRb::Mash.new('code' => code, 'severity' => severity, 'subject' => 'w1', 'message' => 'm')
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
