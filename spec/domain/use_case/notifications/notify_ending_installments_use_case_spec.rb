# frozen_string_literal: true

require "rails_helper"

RSpec.describe UseCase::Notifications::NotifyEndingInstallmentsUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user) }

  before { allow(NotificationsChannel).to receive(:broadcast_to) }

  def pay!(plan, count)
    count.times do |i|
      create(
        :financial_transaction, :expense, :paid,
        user: user,
        installment_plan: plan,
        amount: plan.monthly_amount,
        competency_month: plan.first_competency + i.months,
        installment_number: i + 1
      )
    end
  end

  it "notifies once with the dashboard copy when plans have 1 or 2 remaining installments" do
    router = create(:financial_installment_plan, user: user, description: "Roteador - wifi", total_installments: 2)
    phone  = create(:financial_installment_plan, user: user, description: "Celular", total_installments: 3)
    card   = create(:financial_installment_plan, user: user, description: "Tany - Cartão 2x pagbank", total_installments: 2)
    extra1 = create(:financial_installment_plan, user: user, description: "TV", total_installments: 4)
    extra2 = create(:financial_installment_plan, user: user, description: "Sofá", total_installments: 5)
    far    = create(:financial_installment_plan, user: user, description: "Carro", total_installments: 12)
    pay!(router, 1)
    pay!(phone, 2)
    pay!(extra1, 2)
    pay!(extra2, 3)
    pay!(far, 3)
    create(:financial_installment_plan, description: "Outro usuário", total_installments: 2)

    notification = use_case.call(user: user)

    expect(notification).to have_attributes(
      kind:  "installment_ending",
      title: "Parcelas perto do fim",
      body:            [
        "Falta apenas 1 parcela de Roteador - wifi.",
        "Falta apenas 1 parcela de Celular.",
        "Faltam apenas 2 parcelas de Tany - Cartão 2x pagbank.",
        "+2 outros parcelamentos"
      ].join("\n")
    )
    expect(notification.data).to eq("route" => "/installments")
    expect(notification.dedupe_key).to include(phone.id, router.id, card.id, extra1.id, extra2.id)
    expect(notification.dedupe_key).not_to include(far.id)
    expect(use_case.call(user: user)).to be_nil
  end

  it "skips users without ending plans" do
    plan = create(:financial_installment_plan, user: user, total_installments: 6)
    pay!(plan, 1)

    expect(use_case.call(user: user)).to be_nil
    expect(user.notifications).to be_empty
  end
end
