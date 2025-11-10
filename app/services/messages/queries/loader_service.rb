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
        @user.inbox.messages
             .includes(:outbox, :parent_message,
                       outbox: :user, inbox: :user)
             .order(created_at: :desc)
      end

      # For paginated lists with conversation data
      def inbox_messages_for_user_with_replies
        inbox_messages_for_user
          .includes(replies: %i[inbox outbox])
      end

      # For outbox - minimal includes (no replies)
      def outbox_messages_for_user
        @user.outbox.messages
             .includes(:inbox, :parent_message,
                       inbox: :user, outbox: :user)
             .order(created_at: :desc)
      end

      # For outbox with conversation data
      def outbox_messages_for_user_with_replies
        outbox_messages_for_user
          .includes(replies: %i[inbox outbox])
      end

      # For detail view - full conversation data (class method - no instance state needed)
      def self.find_message_safely(message_id)
        Message.includes(:inbox, :outbox, :parent_message, :prescription,
                         inbox: :user, outbox: :user,
                         parent_message: %i[inbox outbox],
                         replies: %i[inbox outbox],
                         prescription: :payment)
               .find_by(id: message_id)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      # For fetching with prescriptions (class method - no instance state needed)
      def self.messages_with_prescriptions(message_ids)
        Message.where(id: message_ids)
               .includes(:outbox, :prescription,
                         outbox: :user,
                         prescription: :payment)
      end
    end
  end
end
