require "spec_helper"

describe "Process::Queue error handling" do
  class E < RuntimeError; end

  attr_reader :queue
  attr_reader :called_block

  before do
    Postqueue.on "failing" do
      @called_block = true
      raise E
    end
    @queue = Postqueue.new
  end

  context "when handler raises an exception" do
    before do
      queue.enqueue op: "failing", entity_id: 12
    end

    it "keeps the item in the queue and increments the failed_attempt count" do
      begin
        queue.process_one
      rescue
      end

      expect(queue.items.count).to eq(1)
      expect(queue.items.first.attributes).to include("entity_id" => 12, "failed_attempts" => 1)
    end

    it "reraises the exception" do
      expect { queue.process_one }.to raise_error(E)
    end
  end

  context "when no handler can be found" do
    before do
      queue.enqueue op: "unknown", entity_id: 12
    end

    it "raises a MissingHandler exception" do
      expect { queue.process_one }.to raise_error(::Postqueue::MissingHandler)
    end

    it "keeps the item in the queue and increments the failed_attempt count" do
      begin
        queue.process_one
      rescue
      end

      expect(queue.items.count).to eq(1)
      expect(queue.items.first.attributes).to include("entity_id" => 12, "failed_attempts" => 1)
    end
  end

  describe "when failed_attempts reaches max_attemps" do
    before do
      queue.enqueue op: "failing", entity_id: 12
      @queue.items.update_all(failed_attempts: queue.max_attemps)
    end

    it "does not raise an error and returns 0" do
      expect(queue.process_one).to eq(0)
    end

    it "does not run the block" do
      queue.process_one
      expect(called_block).not_to be_truthy
    end

    it "does not remove the item" do
      expect(queue.items.pluck(:entity_id)).to contain_exactly(12)
    end

    it "does not increment the failed_attempts count" do
      expect(queue.items.first.failed_attempts).to eq(queue.max_attemps)
    end
  end
end
