
require 'spec_helper'
require 'rails_helper'

RSpec.describe AuctionCloseJob, type: :job do
  it 'closes auction and creates payment record' do
    auction = create(:auction, ends_at: 1.minute.ago, status: :running)
    create(:bid, auction: auction, amount_cents: 5000)
    expect {
      perform_enqueued_jobs { described_class.perform_now(auction.id) }
    }.to change { auction.reload.status }.from('running').to('closed')
     .and change(PaymentRecord, :count).by(1)
  end
end
