require "spec_helper"

describe "error handling" do
  let(:queue) do
    Postqueue.new do |queue|
      queue.batch_sizes["batchable"] = 10
      queue.batch_sizes["other-batchable"] = 10
    end
  end

  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  class E < RuntimeError; end

  context "when handler raises an exception" do
    before do
      queue.on "mytype" do raise E end
      queue.enqueue op: "mytype", entity_id: 12
    end

    it "reraises the exception, keeps the item in the queue and increments the failed_attempt count" do
      expect { queue.process_one }.to raise_error(E)
      expect(items.map(&:entity_id)).to contain_exactly(12)
      expect(items.map(&:failed_attempts)).to contain_exactly(1)
    end
  end

  context "when no handler can be found" do
    before do
      queue.enqueue op: "mytype", entity_id: 12
    end

    it "raises a MissingHandler exception" do
      expect { queue.process_one }.to raise_error(::Postqueue::MissingHandler)
    end
  end

  context "failed_attempts reached MAX_ATTEMPTS" do
    before do
      expect(queue.max_attemps).to be >= 3
      queue.enqueue op: "mytype", entity_id: 12
      items.update_all(failed_attempts: queue.max_attemps)
      queue.process_one
    end

    it "does not call the block" do
      expect { queue.process_one }.not_to raise_error
    end

    it "returns 0" do
      expect(queue.process_one).to eq(0)
    end

    it "does not remove the item" do
      expect(items.map(&:entity_id)).to contain_exactly(12)
    end

    it "does not increment the failed_attempts count" do
      expect(items.first.failed_attempts).to eq(queue.max_attemps)
    end
  end
end
