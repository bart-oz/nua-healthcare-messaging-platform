# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Messages::Caching::InvalidationService, type: :service do
  let(:sender) { create(:user) }
  let(:recipient) { create(:user) }
  let(:message) { create(:message, outbox: sender.outbox, inbox: recipient.inbox) }

  before do
    allow(Caching::ConversationCacheService).to receive(:invalidate_user_conversations)
    allow(Caching::MessageListCacheService).to receive(:invalidate_conversation_cache)
  end

  describe '.invalidate_conversation_caches' do
    it 'invalidates caches for both participants' do
      expect(Caching::ConversationCacheService).to receive(:invalidate_user_conversations).with(sender.id)
      expect(Caching::ConversationCacheService).to receive(:invalidate_user_conversations).with(recipient.id)

      described_class.invalidate_conversation_caches(message)
    end

    it 'invalidates message list cache for conversation' do
      expect(Caching::MessageListCacheService).to receive(:invalidate_conversation_cache)
        .with(message.inbox_id, message.outbox_id)

      described_class.invalidate_conversation_caches(message)
    end

    context 'when message has no inbox' do
      before { allow(message).to receive(:inbox).and_return(nil) }

      it 'returns early without invalidating' do
        expect(Caching::ConversationCacheService).not_to receive(:invalidate_user_conversations)

        described_class.invalidate_conversation_caches(message)
      end
    end

    context 'when cache invalidation fails' do
      before do
        allow(Caching::ConversationCacheService).to receive(:invalidate_user_conversations)
          .and_raise(StandardError, 'cache unavailable')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and continues gracefully' do
        expect(Rails.logger).to receive(:error).with(/Message cache invalidation failed/)

        expect { described_class.invalidate_conversation_caches(message) }.not_to raise_error
      end
    end
  end
end
