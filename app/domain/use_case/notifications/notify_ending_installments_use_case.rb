# frozen_string_literal: true

class UseCase::Notifications::NotifyEndingInstallmentsUseCase
  THRESHOLD = 2
  PREVIEW   = 3

  def initialize(dispatcher: UseCase::Notifications::DispatchNotificationUseCase.new)
    @dispatcher = dispatcher
  end

  def call(user:)
    ending = ending_plans(user)
    return nil if ending.empty?

    @dispatcher.call(
      user:       user,
      kind:       :installment_ending,
      title:      "Parcelas perto do fim",
      body:       body_for(ending),
      data:       { route: "/installments" },
      dedupe_key: "installment_ending:#{fingerprint(ending)}"
    )
  end

  private

  def ending_plans(user)
    user.installment_plans.status_active.filter_map do |plan|
      remaining = plan.remaining_count
      next unless remaining.positive? && remaining <= THRESHOLD

      [plan, remaining]
    end.sort_by { |_plan, remaining| remaining }
  end

  def body_for(ending)
    lines = ending.first(PREVIEW).map { |plan, remaining| line_for(plan, remaining) }
    extra = ending.size - PREVIEW
    lines << "+#{extra} outros parcelamentos" if extra.positive?
    lines.join("\n")
  end

  def line_for(plan, remaining)
    name = plan.description.to_s.strip
    name = "seu parcelamento" if name.blank?

    if remaining == 1
      "Falta apenas 1 parcela de #{name}."
    else
      "Faltam apenas #{remaining} parcelas de #{name}."
    end
  end

  def fingerprint(ending)
    ending.map { |plan, remaining| "#{plan.id}:#{remaining}" }.sort.join(",")
  end
end
