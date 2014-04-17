require 'spec_helper'

describe "ImpressionCount" do
  class ImpTest
    include Drs::ImpressionCount
    attr_accessor :pid

    def initialize(pid)
      self.pid = pid
    end
  end

  let(:imp) { ImpTest.new("1") }

  it "Returns zero impressions when none have been recorded" do
    imp.impression_views.should == 0
    imp.impression_downloads.should == 0
  end

  it "Returns a single impression when one has been recorded" do
    DrsImpression.create(pid: "1", session_id: "abc", action: "view", ip_address: "121.10.20.1")

    imp.impression_views.should == 1
  end

  it "Knows how to distinguish between impressions" do
    DrsImpression.create(pid: "1", session_id: "def", action: "view", ip_address: "1")
    DrsImpression.create(pid: "1", session_id: "ghi", action: "view", ip_address: "2")
    DrsImpression.create(pid: "1", session_id: "def", action: "view", ip_address: "3") # This should not be counted
    DrsImpression.create(pid: "1", session_id: "def", action: "download", ip_address: "4")
    DrsImpression.create(pid: "2", session_id: "def", action: "view", ip_address: "5")

    imp.impression_views.should == 2
    imp.impression_downloads.should == 1
  end
end
