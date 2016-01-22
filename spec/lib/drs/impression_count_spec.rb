require 'spec_helper'

describe "ImpressionCount" do
  class ImpTest
    include Cerberus::ImpressionCount
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
    Impression.create(pid: "1", session_id: "abc", action: "view", ip_address: "121.10.20.1", referrer: "a", user_agent: "chrome", status: "COMPLETE")

    imp.impression_views.should == 1
  end

  it "Knows how to distinguish between impressions" do
    Impression.create(pid: "1", session_id: "def", action: "view", ip_address: "1", referrer: "a", user_agent: "chrome", status: "COMPLETE")
    Impression.create(pid: "1", session_id: "ghi", action: "view", ip_address: "2", referrer: "a", user_agent: "chrome", status: "COMPLETE")
    Impression.create(pid: "1", session_id: "def", action: "download", ip_address: "4", referrer: "a", user_agent: "chrome", status: "COMPLETE")
    Impression.create(pid: "2", session_id: "def", action: "view", ip_address: "5", referrer: "a", user_agent: "chrome", status: "COMPLETE")

    imp.impression_views.should == 2
    imp.impression_downloads.should == 1
  end

  it "Validates that an impression for an ip address, action and pid, can only be done once an hour" do
    Impression.create(pid: "100", session_id: "def", action: "view", ip_address: "1", referrer: "a", user_agent: "chrome", status: "COMPLETE")
    Impression.create(pid: "100", session_id: "def", action: "view", ip_address: "1", referrer: "a", user_agent: "chrome", status: "COMPLETE").persisted?.should be false
  end
end
