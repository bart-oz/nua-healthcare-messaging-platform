# frozen_string_literal: true

module Broadcasting
  # Handles prescription-specific broadcasting for real-time status updates.
  # Manages patient prescription list updates and status notifications.
  class PrescriptionUpdatesService
    class << self
      # Broadcast prescription status update to patient
      def broadcast_status_update(prescription, notification_message = nil, wait_for_message: false)
        return unless prescription&.user

        # Always use background job for consistency and performance
        BroadcastPrescriptionUpdateJob.perform_later(
          prescription.id,
          notification_message,
          wait_for_message_creation: wait_for_message
        )
      end

      # Broadcast prescription list update when new prescription is added
      def broadcast_prescription_added(prescription)
        return unless prescription&.user

        # Always use background job for consistency
        BroadcastPrescriptionAddedJob.perform_later(prescription.id)
      end

      # Simplified synchronous methods for background jobs to call
      def broadcast_status_update_sync(prescription, notification_message = nil)
        return unless prescription&.user

        broadcast_prescription_item_update(prescription)
        broadcast_prescription_action_button_update(prescription)
        broadcast_inbox_list_item_update(prescription)
        broadcast_notification(prescription.user, notification_message) if notification_message
        broadcast_prescription_count_update(prescription.user)
      end

      def broadcast_prescription_added_sync(prescription)
        return unless prescription&.user

        user = prescription.user

        # Check if this is the first prescription (was empty state)
        was_empty = user.prescriptions.one?

        # Simplified: always prepend to list, let UI handle empty state
        Broadcasting::TurboStreamsService.broadcast_prepend_to(
          prescription_stream(prescription.user),
          target: 'prescriptions-items',
          partial: 'prescriptions/partials/prescription_item',
          locals: { prescription: prescription }
        )

        # If transitioning from empty to first prescription, hide empty state
        if was_empty
          Broadcasting::TurboStreamsService.broadcast_remove_to(
            prescription_stream(user),
            target: 'prescriptions-empty-state'
          )
        end

        # Update pagination info
        Broadcasting::PaginationUpdatesService.enqueue_prescription_pagination_update(prescription.user)
      end

      private

      # Broadcast prescription item update (status change)
      def broadcast_prescription_item_update(prescription)
        Broadcasting::TurboStreamsService.broadcast_replace_to(
          prescription_stream(prescription.user),
          target: dom_id(prescription),
          partial: 'prescriptions/partials/prescription_item',
          locals: { prescription: prescription }
        )
      end

      # Broadcast prescription action button update in admin conversation view
      def broadcast_prescription_action_button_update(prescription)
        return unless prescription.messages.first

        conversation_root = prescription.messages.first.conversation_root
        conversation_stream = Broadcasting::TurboStreamsService.conversation_stream(conversation_root)

        # Broadcast both button and badge updates
        %w[action-button badge].each do |type|
          Broadcasting::TurboStreamsService.broadcast_update_to(
            conversation_stream,
            target: "prescription-#{type}-#{prescription.id}",
            partial: "messages/partials/conversation/prescription_#{type.tr('-', '_')}",
            locals: { prescription: prescription }
          )
        end
      end

      # Broadcast inbox list item update so admins see prescription status changes
      # in real time without refreshing the page.
      def broadcast_inbox_list_item_update(prescription)
        request_message = prescription.messages.includes(:inbox, :outbox, :prescription,
                                                         outbox: :user, prescription: :payment).first
        return unless request_message

        inbox = request_message.inbox
        return unless inbox

        Broadcasting::TurboStreamsService.broadcast_replace_to(
          Broadcasting::TurboStreamsService.inbox_stream(inbox),
          target: ActionView::RecordIdentifier.dom_id(request_message),
          partial: 'messages/partials/list/received_message_item',
          locals: { message: request_message }
        )
      end

      # Broadcast notification to user
      def broadcast_notification(user, message)
        Broadcasting::TurboStreamsService.broadcast_update_to(
          prescription_stream(user),
          target: 'global-notifications',
          partial: 'shared/notification',
          locals: { message: message, type: 'info', auto_dismiss: true }
        )
      end

      # Broadcast prescription count update
      def broadcast_prescription_count_update(user)
        Broadcasting::TurboStreamsService.broadcast_update_to(
          Broadcasting::TurboStreamsService.inbox_stream(user.inbox),
          target: 'prescription-count-badge',
          partial: 'prescriptions/partials/count_badge',
          locals: { count: user.prescriptions.count }
        )
      end

      # Get prescription stream name for user
      def prescription_stream(user)
        "user_#{user.id}_prescriptions"
      end

      # Generate DOM ID for prescription using Rails helper pattern
      def dom_id(prescription)
        "prescription_#{prescription.id}"
      end
    end
  end
end
