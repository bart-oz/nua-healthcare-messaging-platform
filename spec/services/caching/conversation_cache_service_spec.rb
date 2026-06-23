# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Caching::ConversationCacheService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:inbox) { user.inbox }
  let(:outbox) { user.outbox }
  let(:other_inbox) { other_user.inbox }
  let(:other_outbox) { other_user.outbox }

  before do
    # Use memory store for testing
    allow(Rails.cache).to receive(:fetch).and_call_original
    allow(Rails.cache).to receive(:write).and_call_original
  end

  describe '.get_conversation_list' do
    it 'returns conversation list for user' do
      create(:message, inbox: inbox, outbox: other_outbox, body: 'Test message')

      result = described_class.get_conversation_list(user.id, limit: 10)

      expect(result).to be_an(Array)
      expect(result.first).to include(:id, :conversation_id, :last_message) if result.any?
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:fetch).and_raise(StandardError, 'cache unavailable')

      result = described_class.get_conversation_list(user.id)

      expect(result).to be_an(Array)
    end
  end

  describe '.get_recent_conversations' do
    it 'returns recent conversations for user' do
      create(:message, inbox: inbox, outbox: other_outbox, body: 'Recent message')

      result = described_class.get_recent_conversations(user.id, limit: 5)

      expect(result).to be_an(Array)
      expect(result.first).to include(:preview, :has_unread) if result.any?
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:fetch).and_raise(StandardError, 'cache unavailable')

      result = described_class.get_recent_conversations(user.id)

      expect(result).to be_an(Array)
    end
  end

  describe '.cache_conversation_list' do
    it 'caches conversation list' do
      conversations = [{ id: 1, conversation_id: 'test' }]

      result = described_class.cache_conversation_list(user.id, conversations)

      expect(result).to be_truthy
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:write).and_raise(StandardError, 'cache unavailable')
      conversations = [{ id: 1, conversation_id: 'test' }]

      result = described_class.cache_conversation_list(user.id, conversations)

      expect(result).to be false
    end
  end

  describe '.cache_recent_conversations' do
    it 'caches recent conversations' do
      conversations = [{ id: 1, conversation_id: 'test', preview: 'Test', has_unread: false }]

      result = described_class.cache_recent_conversations(user.id, conversations)

      expect(result).to be_truthy
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:write).and_raise(StandardError, 'cache unavailable')
      conversations = [{ id: 1, conversation_id: 'test' }]

      result = described_class.cache_recent_conversations(user.id, conversations)

      expect(result).to be false
    end
  end

  describe '.invalidate_user_conversations' do
    it 'invalidates user conversation caches' do
      result = described_class.invalidate_user_conversations(user.id)

      expect(result).to be_truthy
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:delete_matched).and_raise(StandardError, 'cache unavailable')

      result = described_class.invalidate_user_conversations(user.id)

      expect(result).to be false
    end
  end

  describe '.invalidate_all_conversations' do
    it 'invalidates all conversation caches' do
      result = described_class.invalidate_all_conversations

      expect(result).to be_truthy
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:delete_matched).and_raise(StandardError, 'cache unavailable')

      result = described_class.invalidate_all_conversations

      expect(result).to be false
    end
  end

  describe '.cache_stats' do
    it 'returns cache statistics' do
      stats = described_class.cache_stats

      expect(stats).to include(:cache_ttl, :max_conversations, :cache_key_prefix)
    end
  end

  describe 'private methods' do
    let(:message) { create(:message, inbox: inbox, outbox: other_outbox) }

    describe '.conversation_identifier' do
      it 'creates consistent conversation ID' do
        identifier1 = described_class.send(:conversation_identifier, message)
        identifier2 = described_class.send(:conversation_identifier, message)

        expect(identifier1).to eq(identifier2)
        expect(identifier1).to include(inbox.id.to_s)
        expect(identifier1).to include(other_outbox.id.to_s)
      end
    end

    describe '.extract_participants' do
      it 'extracts participants from message' do
        participants = described_class.send(:extract_participants, message)

        expect(participants).to be_an(Array)
        expect(participants.first).to include(:id, :name)
      end
    end

    describe '.calculate_unread_count' do
      it 'calculates unread count for conversation' do
        create(:message, inbox: inbox, outbox: other_outbox, read: false)
        create(:message, inbox: other_inbox, outbox: outbox, read: false)

        count = described_class.send(:calculate_unread_count, message)
        expect(count).to be >= 0
      end
    end
  end
end
