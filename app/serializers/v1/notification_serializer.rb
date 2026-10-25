# frozen_string_literal: true

module V1
  class NotificationSerializer < Blueprinter::Base
    identifier :id

    view :default do
      fields :kind, :title, :body, :data, :read_at, :created_at
      field(:group) { |notification| notification.group }
      field(:read)  { |notification| notification.read? }
    end

    view :extended do
      include_view :default
      fields :channels, :dedupe_key, :updated_at
    end
  end
end
