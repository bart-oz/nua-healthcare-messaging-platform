# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Caching::UnreadCountService do
  let(:user) { create(:user) }
  let(:inbox) { user.inbox }
  let(:outbox) { create(:outbox, user: create(:user, is_doctor: true)) }

  before do
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    inbox.update!(unread_count: 0)
  end

  after do
    Rails.cache = @original_cache_store
  end

  describe '.get_unread_count' do
    context 'when cache is available' do
      it 'returns cached count when available' do
        Rails.cache.write("inbox_unread_count:#{inbox.id}", 5, expires_in: 5.minutes)

        expect(described_class.get_unread_count(inbox)).to eq(5)
      end

      it 'fetches from database and caches on miss' do
        inbox.messages.destroy_all

        message_data = [
          {
            id: SecureRandom.uuid,
            body: 'Test 1',
            inbox_id: inbox.id,
            outbox_id: outbox.id,
            read: false,
            created_at: Time.current,
            updated_at: Time.current
          },
          {
            id: SecureRandom.uuid,
            body: 'Test 2',
            inbox_id: inbox.id,
            outbox_id: outbox.id,
            read: false,
            created_at: Time.current,
            updated_at: Time.current
          },
          {
            id: SecureRandom.uuid,
            body: 'Test 3',
            inbox_id: inbox.id,
            outbox_id: outbox.id,
            read: false,
            created_at: Time.current,
            updated_at: Time.current
          }
        ]
        Message.insert_all(message_data)

        expect(described_class.get_unread_count(inbox)).to eq(3)

        expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(3)
      end
    end

    context 'when cache is not available' do
      before do
        allow(Rails.cache).to receive(:read).and_raise(StandardError, 'cache unavailable')
        allow(Rails.cache).to receive(:write).and_raise(StandardError, 'cache unavailable')
      end

      it 'falls back to database count' do
        create_list(:message, 2, inbox: inbox, read: false)

        expect(described_class.get_unread_count(inbox)).to eq(2)
      end
    end
  end

  describe '.increment_unread_count' do
    it 'increments cached count' do
      Rails.cache.write("inbox_unread_count:#{inbox.id}", 3, expires_in: 5.minutes)

      described_class.increment_unread_count(inbox)

      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(4)
    end

    it 'handles cache miss by fetching from database' do
      inbox.messages.destroy_all

      message_data = [
        {
          id: SecureRandom.uuid,
          body: 'Test 1',
          inbox_id: inbox.id,
          outbox_id: outbox.id,
          read: false,
          created_at: Time.current,
          updated_at: Time.current
        },
        {
          id: SecureRandom.uuid,
          body: 'Test 2',
          inbox_id: inbox.id,
          outbox_id: outbox.id,
          read: false,
          created_at: Time.current,
          updated_at: Time.current
        }
      ]
      Message.insert_all(message_data)

      described_class.increment_unread_count(inbox)

      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(3)
    end
  end

  describe '.decrement_unread_count' do
    it 'decrements cached count' do
      Rails.cache.write("inbox_unread_count:#{inbox.id}", 5, expires_in: 5.minutes)

      described_class.decrement_unread_count(inbox)

      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(4)
    end

    it 'does not go below zero' do
      Rails.cache.write("inbox_unread_count:#{inbox.id}", 0, expires_in: 5.minutes)

      described_class.decrement_unread_count(inbox)

      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(0)
    end
  end

  describe '.reset_unread_count' do
    it 'resets cached count to zero' do
      Rails.cache.write("inbox_unread_count:#{inbox.id}", 10, expires_in: 5.minutes)

      described_class.reset_unread_count(inbox)

      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(0)
    end
  end

  describe '.invalidate_cache' do
    it 'removes cached count' do
      Rails.cache.write("inbox_unread_count:#{inbox.id}", 5, expires_in: 5.minutes)

      described_class.invalidate_cache(inbox)

      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to be_nil
    end
  end

  describe '.recalculate_and_cache' do
    it 'recalculates from database and caches result' do
      create_list(:message, 4, inbox: inbox, read: false)

      result = described_class.recalculate_and_cache(inbox)

      expect(result).to eq(4)
      expect(Rails.cache.read("inbox_unread_count:#{inbox.id}")).to eq(4)
    end
  end

  describe '.cache_stats' do
    it 'returns cache statistics' do
      stats = described_class.cache_stats

      expect(stats).to include(
        cache_available: true,
        cache_ttl: 10.minutes,
        cache_key_prefix: 'inbox_unread_count'
      )
    end
  end
end
