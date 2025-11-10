# frozen_string_literal: true

module Messages
  module Queries
    # Simple message loading service for controllers.
    # Returns properly configured ActiveRecord relations for pagination.
    class LoaderService
      def initialize(user)
        @user = user
      end

      # For paginated lists - minimal includes (no replies)
      def inbox_messages_for_user
        @user.inbox.messages.with_basic_data.order(created_at: :desc)
      end

      # For paginated lists with conversation data
      def inbox_messages_for_user_with_replies
        @user.inbox.messages.with_full_conversation.order(created_at: :desc)
      end

      # For outbox - minimal includes (no replies)
      def outbox_messages_for_user
        @user.outbox.messages.with_basic_data.order(created_at: :desc)
      end

      # For outbox with conversation data
      def outbox_messages_for_user_with_replies
        @user.outbox.messages.with_full_conversation.order(created_at: :desc)
      end

      # For detail view - full conversation data (class method - no instance state needed)
      def self.find_message_safely(message_id)
        Message.with_full_context.find_by(id: message_id)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      # For fetching with prescriptions (class method - no instance state needed)
      def self.messages_with_prescriptions(message_ids)
        Message.where(id: message_ids).with_prescriptions
      end
    end
  end
end
