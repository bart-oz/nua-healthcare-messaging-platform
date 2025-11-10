# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Messages::Queries::LoaderService, type: :service do
  let(:patient) { create(:user, is_patient: true) }
  let(:doctor) { create(:user, is_doctor: true) }
  let(:service) { described_class.new(patient) }

  describe '#inbox_messages_for_user' do
    let!(:messages) { create_list(:message, 3, inbox: patient.inbox, outbox: doctor.outbox) }

    it 'loads messages with minimal associations by default' do
      result = service.inbox_messages_for_user

      expect(result.count).to eq(3)
      expect(result).to all(be_a(Message))
    end

    it 'includes outbox user by default' do
      result = service.inbox_messages_for_user.first

      expect { result.outbox.user }.not_to raise_error
    end

    it 'does not load replies by default' do
      message_with_replies = messages.first
      create_list(:message, 2, parent_message: message_with_replies)

      result = service.inbox_messages_for_user.find(message_with_replies.id)

      # Verify replies are not preloaded
      expect(result.association(:replies).loaded?).to be false
    end

    it 'loads replies when explicitly requested' do
      message_with_replies = messages.first
      create_list(:message, 2, parent_message: message_with_replies)

      result = service.inbox_messages_for_user_with_replies.find(message_with_replies.id)

      expect(result.association(:replies).loaded?).to be true
    end
  end

  describe '#outbox_messages_for_user' do
    let!(:messages) { create_list(:message, 3, inbox: doctor.inbox, outbox: patient.outbox) }

    it 'loads messages with minimal associations by default' do
      result = service.outbox_messages_for_user

      expect(result.count).to eq(3)
    end

    it 'loads replies when explicitly requested' do
      message_with_replies = messages.first
      create_list(:message, 2, parent_message: message_with_replies)

      result = service.outbox_messages_for_user_with_replies.find(message_with_replies.id)

      expect(result.association(:replies).loaded?).to be true
    end
  end

  describe '.find_message_safely' do
    let(:message) { create(:message, inbox: patient.inbox, outbox: doctor.outbox) }

    it 'returns the message when found' do
      result = described_class.find_message_safely(message.id)
      expect(result).to eq(message)
    end

    it 'returns nil when message not found' do
      result = described_class.find_message_safely('nonexistent-id')
      expect(result).to be_nil
    end

    it 'loads all conversation data including replies' do
      create_list(:message, 2, parent_message: message)

      result = described_class.find_message_safely(message.id)

      expect(result.association(:replies).loaded?).to be true
      expect(result.association(:prescription).loaded?).to be true
    end
  end

  describe '.messages_with_prescriptions' do
    let!(:message) { create(:message, inbox: patient.inbox) }

    it 'loads messages with prescriptions' do
      result = described_class.messages_with_prescriptions([message.id])

      expect(result).to include(message)
      expect(result.first.association(:prescription).loaded?).to be true
    end
  end
end
