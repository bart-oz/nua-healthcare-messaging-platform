# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Caching::WarmingService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    Message.delete_all
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rails.cache = @original_cache_store
  end

  describe '.warm_unread_counts' do
    it 'warms unread count caches' do
      create_list(:message, 2, inbox: user.inbox, read: false)
      result = described_class.warm_unread_counts
      expect(result[:warmed]).to eq(1)
    end

    it 'returns 0 when no active inboxes' do
      result = described_class.warm_unread_counts
      expect(result[:warmed]).to eq(0)
    end
  end

  describe '.warm_user_inbox' do
    it 'warms cache for specific user' do
      create_list(:message, 3, inbox: user.inbox, read: false)
      described_class.warm_user_inbox(user)
      expect(Rails.cache.read("inbox_unread_count:#{user.inbox.id}")).to eq(3)
    end

    it 'handles user without inbox' do
      user_without_inbox = build(:user, inbox: nil)
      expect { described_class.warm_user_inbox(user_without_inbox) }.not_to raise_error
    end
  end

  describe '.warm_multiple_users' do
    it 'warms cache for multiple users' do
      create_list(:message, 2, inbox: user.inbox, read: false)
      create_list(:message, 1, inbox: other_user.inbox, read: false)

      expect(Caching::UnreadCountService).to receive(:recalculate_and_cache).twice

      described_class.warm_multiple_users([user, other_user])
    end
  end

  describe '.warm_conversation_caches' do
    it 'warms conversation caches for active users' do
      create(:message, inbox: user.inbox, outbox: other_user.outbox, created_at: 1.day.ago)

      expect(Caching::ConversationCacheService).to receive(:get_recent_conversations).with(user.id, limit: 10)
      expect(Caching::ConversationCacheService).to receive(:cache_recent_conversations).with(user.id, anything,
                                                                                             limit: 10)

      result = described_class.warm_conversation_caches
      expect(result).to eq(1)
    end

    it 'returns 0 when no active users' do
      result = described_class.warm_conversation_caches
      expect(result).to eq(0)
    end
  end

  describe '.warm_message_list_caches' do
    it 'warms message list caches for recent conversations' do
      create(:message, inbox: user.inbox, outbox: other_user.outbox, created_at: 1.day.ago)

      expect(Caching::MessageListCacheService).to receive(:get_conversation_thread)
        .with(user.inbox.id, other_user.outbox.id, limit: 50)
      expect(Caching::MessageListCacheService).to receive(:cache_conversation_thread)
        .with(user.inbox.id, other_user.outbox.id, anything, limit: 50)

      result = described_class.warm_message_list_caches
      expect(result).to eq(1)
    end

    it 'returns 0 when no recent conversations' do
      result = described_class.warm_message_list_caches
      expect(result).to eq(0)
    end
  end

  describe '.warming_stats' do
    it 'returns warming statistics' do
      stats = described_class.warming_stats
      expect(stats).to include(:cache_available, :last_warmed_at, :warmed_count)
    end
  end

  describe '.schedule_warming' do
    it 'schedules warming and updates statistics' do
      create(:message, inbox: user.inbox, read: false)
      described_class.schedule_warming
      stats = described_class.warming_stats
      expect(stats[:warmed_count]).to be >= 0
    end
  end

  describe '.cache_available?' do
    it 'returns true when cache is available' do
      expect(described_class.send(:cache_available?)).to be true
    end

    it 'returns false when cache access fails' do
      allow(Rails.cache).to receive(:respond_to?).and_raise(StandardError, 'cache unavailable')
      expect(described_class.send(:cache_available?)).to be false
    end
  end
end
