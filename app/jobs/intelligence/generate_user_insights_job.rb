# frozen_string_literal: true

module Intelligence
  class GenerateUserInsightsJob < ApplicationJob
    queue_as :insights

    def perform(user, month = nil)
      insights = UseCase::Intelligence::GenerateInsightsUseCase.new.call(user: user, month: month)
      return if insights.empty?

      UseCase::Notifications::DispatchNotificationUseCase.new.call(
        user:       user,
        kind:       :insights_ready,
        title:      "#{insights.size} #{insights.size == 1 ? 'novo insight' : 'novos insights'} sobre o seu mês",
        body:       insights.first.content.truncate(140),
        data:       { route: "/dashboard" },
        dedupe_key: "insights_ready:#{Date.current}"
      )
    end
  end
end
