# frozen_string_literal: true

describe Sbmt::Outbox::ProcessItemsJob do
  it { expect(described_class.item_classes).to eq [OutboxItem] }
end
