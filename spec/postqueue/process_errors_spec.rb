require "spec_helper"

describe "error handling" do
  class E < RuntimeError; end

  attr_reader :queue

  before do
    Postqueue.on "mytype" do
      raise E
    end
  end

  context "when handler raises an exception" do
    before do
      @queue = Postqueue.new
      @queue.enqueue op: "mytype", entity_id: 12
    end

    it "reraises the exception, keeps the item in the queue and increments the failed_attempt count" do
      expect { queue.process_one }.to raise_error(E)

      expect(queue.items.pluck(:entity_id)).to contain_exactly(12)
      expect(queue.items.pluck(:failed_attempts)).to contain_exactly(1)
    end
  end

  context "when no handler can be found" do
    before do
      @queue = Postqueue.new
      @queue.enqueue op: "unknown", entity_id: 12
    end

    it "raises a MissingHandler exception" do
      expect { queue.process_one }.to raise_error(::Postqueue::MissingHandler)
    end
  end

  context "failed_attempts reached MAX_ATTEMPTS" do
    before do
      @queue = Postqueue.new

      @queue.enqueue op: "mytype", entity_id: 12
      @queue.items.update_all(failed_attempts: queue.max_attemps)
    end

    it "verifies that the queue is configured with max_attemps >= 3" do
      expect(queue.max_attemps).to be >= 3
    end

    it "does not call the block" do
      expect { queue.process_one }.not_to raise_error
    end

    it "returns 0" do
      expect(queue.process_one).to eq(0)
    end

    it "does not remove the item" do
      expect(queue.items.pluck(:entity_id)).to contain_exactly(12)
    end

    it "does not increment the failed_attempts count" do
      expect(queue.items.first.failed_attempts).to eq(queue.max_attemps)
    end
  end
end
