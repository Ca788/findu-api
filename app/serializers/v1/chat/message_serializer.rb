# frozen_string_literal: true

module V1
  module Chat
    class MessageSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :role, :kind, :body, :status, :intent, :conversation_id,
               :parent_message_id, :client_message_id, :created_at, :updated_at

        field :audio_url do |message|
          next nil unless message.audio.attached?

          Rails.application.routes.url_helpers.rails_storage_proxy_path(message.audio, only_path: true)
        end

        field :attachments do |message|
          next [] unless message.attachments.attached?

          message.attachments.map do |att|
            {
              id:           att.id,
              filename:     att.filename.to_s,
              content_type: att.content_type,
              byte_size:    att.byte_size,
              url:          Rails.application.routes.url_helpers.rails_blob_path(att, only_path: true)
            }
          end
        end

        field :actions do |message|
          payload = message.payload
          next [] unless payload.is_a?(Hash)

          payload["actions"] || payload[:actions] || []
        end

        field :card do |message|
          payload = message.payload
          next nil unless payload.is_a?(Hash)

          payload["card"] || payload[:card]
        end
      end

      view :extended do
        include_view :default

        fields :payload, :error
      end
    end
  end
end
