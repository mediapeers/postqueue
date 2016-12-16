require "spec_helper"

describe "default_queue" do
  let(:queue) { Postqueue }
  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  let(:processed_events) { @processed_events ||= [] }

  before do
    queue.batch_sizes["batchable"] = 10
    queue.batch_sizes["other-batchable"] = 10

    queue.on "*" do |op, entity_ids|
      processed_events << [ op, entity_ids ]
    end

    queue.enqueue op: "batchable", entity_id: 12
    queue.enqueue op: "batchable", entity_id: 13
    queue.enqueue op: "other-batchable", entity_id: 14
    queue.enqueue op: "batchable", entity_id: 15
    queue.enqueue op: "other-batchable", entity_id: 16
  end

  it "processes one matching entry with batch_size 1" do
    r = queue.process batch_size: 1
    expect(r).to eq(1)
    expect(items.map(&:entity_id)).to contain_exactly(13, 14, 15, 16)
  end

  it "processes all matching entries" do
    r = queue.process
    expect(r).to eq(3)
    expect(items.map(&:entity_id)).to contain_exactly(14, 16)
  end

  it "honors search conditions" do
    r = queue.process(op: "other-batchable")
    expect(r).to eq(2)
    expect(items.map(&:entity_id)).to contain_exactly(12, 13, 15)
  end
end
