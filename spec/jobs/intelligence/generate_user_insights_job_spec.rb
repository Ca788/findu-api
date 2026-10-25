# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intelligence::GenerateUserInsightsJob, type: :job do
  let(:user) { create(:user) }
  let(:use_case) { instance_double(UseCase::Intelligence::GenerateInsightsUseCase) }

  before do
    allow(UseCase::Intelligence::GenerateInsightsUseCase).to receive(:new).and_return(use_case)
    allow(NotificationsChannel).to receive(:broadcast_to)
  end

  it "notifies once a day when insights were generated" do
    insights = [
      user.insights.create!(reference_type: Intelligence::Insight::REFERENCE_MONTHLY_STATEMENT, content: "Você gastou 30% a mais com delivery."),
      user.insights.create!(reference_type: Intelligence::Insight::REFERENCE_MONTHLY_STATEMENT, content: "Reserve R$ 200 para o IPVA.")
    ]
    allow(use_case).to receive(:call).and_return(insights)

    described_class.perform_now(user)
    described_class.perform_now(user)

    notification = user.notifications.where(kind: "insights_ready").sole
    expect(notification.title).to eq("2 novos insights sobre o seu mês")
    expect(notification.body).to eq("Você gastou 30% a mais com delivery.")
    expect(notification.data).to eq("route" => "/dashboard")
  end

  it "stays silent when nothing was generated" do
    allow(use_case).to receive(:call).and_return([])

    described_class.perform_now(user)

    expect(user.notifications).to be_empty
  end
end
