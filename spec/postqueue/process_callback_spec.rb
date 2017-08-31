require "spec_helper"

describe "Process::Queue processing" do
  let(:processed_events) do
    @processed_events ||= []
  end

  let(:queue) do
    Postqueue.on "args/1" do |op|
      processed_events << [ op ]
    end
    Postqueue.on "args/2" do |op, entity_ids|
      processed_events << [ op, entity_ids ]
    end
    Postqueue.on "args/3" do |op, entity_ids, items|
      processed_events << [ op, entity_ids, items ]
    end
    Postqueue.new
  end

  describe "callback arguments" do
    before do
      queue.enqueue op: "args/1", entity_id: 12
      queue.enqueue op: "args/2", entity_id: 13
      queue.enqueue op: "args/3", entity_id: 14

      queue.process_until_empty
    end

    it "callbacks with one argument receive the op value" do
      event = processed_events[0]
      expect(event).to eq(["args/1"])
    end

    it "callbacks with two arguments receive the op and entity_id values" do
      event = processed_events[1]
      expect(event).to eq(["args/2", [13]])
    end

    it "callbacks with three arguments receive the op, entity_id values and array of items" do
      event = processed_events[2]
      expect(event[0]).to eq("args/3")
      expect(event[1]).to eq([14])
      expect(event[2]).to be_a(Array)
      expect(event[2].length).to eq(1)
      item = event[2].first
      expect(item).to be_a(Hash)
      expect(item).to include(op: "args/3", entity_id: 14)
    end
  end
end
