# frozen_string_literal: true

describe Sbmt::Outbox::BaseItem do
  describe "#max_retries_exceeded?" do
    let(:outbox_item) { Fabricate(:outbox_item) }

    before do
      allow(outbox_item.config).to receive(:max_retries).and_return(1)
    end

    it "has available retries" do
      expect(outbox_item).not_to be_max_retries_exceeded
    end

    context "when item was retried" do
      let(:outbox_item) { Fabricate(:outbox_item, errors_count: 2) }

      it "has not available retries" do
        expect(outbox_item).to be_max_retries_exceeded
      end
    end
  end

  describe "#options" do
    let(:outbox_item) { Fabricate(:outbox_item) }
    let(:dispatched_at_header_name) { Sbmt::Outbox::OutboxItem::DISPATCH_TIME_HEADER_NAME }

    it "returns valid options" do
      def outbox_item.extra_options
        {
          foo: true,
          bar: true
        }
      end

      outbox_item.options = {bar: false}

      expect(outbox_item.options).to include(:headers, :foo, :bar)
      expect(outbox_item.options[:bar]).to be false
    end

    it "has 'Dispatched-At' header" do
      expect(outbox_item.options[:headers].has_key?(dispatched_at_header_name)).to be(true)
    end
  end

  describe "#add_error" do
    let(:outbox_item) { Fabricate(:outbox_item) }

    it "saves exception message to record" do
      error = StandardError.new("test-error")
      outbox_item.add_error(error)
      outbox_item.save!
      outbox_item.reload

      expect(outbox_item.error_log).to include("test-error")

      error = StandardError.new("another-error")
      outbox_item.add_error(error)
      outbox_item.save!
      outbox_item.reload

      expect(outbox_item.error_log).to include("another-error")
    end
  end

  describe "#partition" do
    let(:outbox_item) { Fabricate.build(:outbox_item, bucket: 3) }

    it "returns valid partition" do
      expect(outbox_item.partition).to eq 1
    end
  end

  describe ".partition_buckets" do
    it "returns buckets of partitions" do
      expect(OutboxItem.partition_buckets).to eq(0 => [0, 2], 1 => [1, 3])
    end

    context "when the number of partitions is not a multiple of the number of buckets" do
      before do
        if OutboxItem.instance_variable_defined?(:@partition_buckets)
          OutboxItem.remove_instance_variable(:@partition_buckets)
        end

        allow(OutboxItem.config).to receive_messages(partition_size: 2, bucket_size: 5)
      end

      after do
        OutboxItem.remove_instance_variable(:@partition_buckets)
      end

      it "returns buckets of partitions" do
        expect(OutboxItem.partition_buckets).to eq(0 => [0, 2, 4], 1 => [1, 3])
      end
    end
  end

  describe ".bucket_partitions" do
    it "returns buckets of partitions" do
      expect(OutboxItem.bucket_partitions).to eq(0 => 0, 1 => 1, 2 => 0, 3 => 1)
    end
  end

  describe "#transports" do
    context "when transport was built by factory" do
      let(:outbox_item) { Fabricate.build(:outbox_item) }

      it "returns valid transports" do
        expect(outbox_item.transports.size).to eq 1
        expect(outbox_item.transports.first).to be_a(Producer)
        expect(outbox_item.transports.first.topic).to eq "outbox_item_topic"
        expect(outbox_item.transports.first.kafka).to include("required_acks" => -1)
      end
    end

    context "when transport was built by name" do
      let(:inbox_item) { Fabricate.build(:inbox_item) }

      it "returns valid transports" do
        expect(inbox_item.transports.size).to eq 1
        expect(inbox_item.transports.first).to be_a(ImportOrder)
        expect(inbox_item.transports.first.source).to eq "kafka_consumer"
      end
    end

    context "when transports were selected by event name" do
      let(:outbox_item) { Fabricate.build(:combined_outbox_item, event_name: "orders_completed") }

      it "returns valid transports" do
        expect(outbox_item.transports.size).to eq 1
        expect(outbox_item.transports.first).to be_a(Producer)
        expect(outbox_item.transports.first.topic).to eq "orders_completed_topic"
      end
    end
  end
end
