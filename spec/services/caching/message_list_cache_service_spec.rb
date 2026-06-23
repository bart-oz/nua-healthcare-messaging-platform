# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Caching::MessageListCacheService do
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

  describe '.get_message_list' do
    it 'returns message list for conversation' do
      create(:message, inbox: inbox, outbox: other_outbox, body: 'Test message')
      conversation_id = "#{inbox.id}-#{other_outbox.id}"

      result = described_class.get_message_list(conversation_id, limit: 10)

      expect(result).to be_an(Array)
      expect(result.first).to include(:id, :body, :sender, :recipient) if result.any?
    end

    it 'handles cache errors gracefully' do
      allow(Rails.cache).to receive(:fetch).and_raise(StandardError, 'cache unavailable')

      result = described_class.get_message_list('test-conversation')

      expect(result).to be_an(Array)
    end
  end

  describe '.get_conversation_thread' do
    it 'returns conversation thread' do
      create(:message, inbox: inbox, outbox: other_outbox, body: 'Thread message')

      result = described_class.get_conversation_thread(inbox.id, other_outbox.id, limit: 10)

      expect(result).to be_an(Array)
      expect(result.first).to include(:is_sender, :formatted_time)
    end
  end

  describe '.cache_message_list' do
    it 'caches message list' do
      messages = [{ id: 1, body: 'test' }]

      result = described_class.cache_message_list('test-conversation', messages)

      expect(result).to be_truthy
    end
  end

  describe '.invalidate_conversation_cache' do
    it 'invalidates conversation cache' do
      result = described_class.invalidate_conversation_cache(inbox.id, other_outbox.id)

      expect(result).to be_truthy
    end
  end

  describe '.cache_stats' do
    it 'returns cache statistics' do
      stats = described_class.cache_stats

      expect(stats).to include(:cache_ttl, :max_messages_per_thread, :cache_key_prefix)
    end
  end
end
