# frozen_string_literal: true

class RemoveRedundantMessageIndexes < ActiveRecord::Migration[7.2]
  def change
    # Remove redundant single-column indexes that are covered by compound indexes
    remove_index :messages, :inbox_id, if_exists: true
    remove_index :messages, :outbox_id, if_exists: true
    remove_index :messages, :parent_message_id, if_exists: true
    remove_index :messages, :routing_type, if_exists: true,
                                           name: 'idx_messages_routing_type'
    remove_index :messages, :status, if_exists: true
    remove_index :messages, :read_at, if_exists: true,
                                      name: 'idx_messages_read_at'
    remove_index :messages, %i[inbox_id read], if_exists: true,
                                               where: 'read = false',
                                               name: 'idx_messages_inbox_read_status'
  end
end
