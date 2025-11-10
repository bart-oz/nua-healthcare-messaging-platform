# frozen_string_literal: true

module Api
  module V1
    class InboxesController < BaseController
      before_action :initialize_loader_service

      # GET /api/v1/inbox/messages
      def messages
        messages = @loader_service.inbox_messages_for_user.limit(50)
        render_collection(messages, MessageSerializer)
      end

      # GET /api/v1/inbox/conversations
      def conversations
        conversation_roots = @loader_service.inbox_messages_for_user_with_replies
                                            .where(parent_message_id: nil)
                                            .limit(10)
        render_collection(conversation_roots, ConversationSerializer)
      end

      # GET /api/v1/inbox/unread
      def unread
        unread_count = current_user.inbox.messages.where(read: false).count
        render_success({ unread_count: unread_count })
      end

      private

      def initialize_loader_service
        @loader_service = Messages::Queries::LoaderService.new(current_user)
      end
    end
  end
end
