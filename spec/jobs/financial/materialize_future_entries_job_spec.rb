# frozen_string_literal: true

require "rails_helper"

RSpec.describe Financial::MaterializeFutureEntriesJob, type: :job do
  let(:user) { create(:user) }

  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  it "completes fully paid plans and notifies the user once" do
    plan = create(:financial_installment_plan, user: user, total_installments: 2, monthly_amount: 500, total_amount: 1000)
    2.times do |i|
      create(:financial_transaction, :expense, :paid, user: user, installment_plan: plan, amount: 500,
             competency_month: plan.first_competency + i.months, installment_number: i + 1)
    end
    open_plan = create(:financial_installment_plan, user: user)
    create(:financial_transaction, :expense, :paid, user: user, installment_plan: open_plan, amount: 500)

    described_class.perform_now
    described_class.perform_now

    expect(plan.reload.status).to eq("completed")
    expect(open_plan.reload.status).to eq("active")

    notification = user.notifications.where(kind: "installment_completed").sole
    expect(notification.title).to eq("Parcelamento quitado: Celular")
    expect(notification.body).to eq("2 parcelas pagas, R$ 1.000,00 no total.")
    expect(notification.data).to include("route" => "/installments", "installment_plan_id" => plan.id)
  end
end
