# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::NotifyEndingInstallmentsJob, type: :job do
  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  it "notifies each active user with ending plans and skips deleted users" do
    user    = create(:user)
    deleted = create(:user, deleted_at: Time.current)
    create(:financial_installment_plan, user: user, description: "Celular", total_installments: 2)
    create(:financial_installment_plan, user: deleted, description: "Celular", total_installments: 2)

    described_class.perform_now
    described_class.perform_now

    expect(user.notifications.where(kind: "installment_ending").sole.title).to eq("Parcelas perto do fim")
    expect(deleted.notifications).to be_empty
  end
end
