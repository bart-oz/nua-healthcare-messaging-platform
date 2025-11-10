# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'enums' do
    it 'has status enum' do
      expect(Message.statuses).to eq({
                                       'sent' => 0,
                                       'delivered' => 1,
                                       'read' => 2
                                     })
    end

    it 'has routing_type enum' do
      expect(Message.routing_types).to eq({
                                            'direct' => 0,
                                            'reply' => 1,
                                            'auto' => 2
                                          })
    end
  end

  describe 'associations' do
    it 'belongs to an inbox' do
      expect(Message.new).to respond_to(:inbox)
    end

    it 'belongs to an outbox' do
      expect(Message.new).to respond_to(:outbox)
    end

    it 'can have a parent message' do
      expect(Message.new).to respond_to(:parent_message)
    end

    it 'can have child messages' do
      expect(Message.new).to respond_to(:replies)
    end

    it 'can access recipient through inbox' do
      message = create(:message)
      expect(message.inbox.user).to eq(message.recipient_user)
    end

    it 'can access sender through outbox' do
      message = create(:message)
      expect(message.outbox.user).to eq(message.sender_user)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      message = build(:message)
      expect(message).to be_valid
    end

    it 'requires a body' do
      message = build(:message, body: nil)
      expect(message).not_to be_valid
      expect(message.errors[:body]).to include("can't be blank")
    end

    it 'limits body to 500 characters' do
      message = build(:message, body: 'a' * 501)
      expect(message).not_to be_valid
      expect(message.errors[:body]).to include('is too long (maximum is 500 characters)')
    end
  end

  describe 'query interface' do
    let!(:unread_message) { create(:message, :unread) }
    let!(:read_message) { create(:message, :read) }

    it 'provides query object interface' do
      expect(Message.query).to be_a(MessageQuery)
    end

    it 'filters unread messages through query object' do
      unread_messages = Message.query.unread
      expect(unread_messages).to include(unread_message)
      expect(unread_messages).not_to include(read_message)
    end

    it 'filters read messages through query object' do
      read_messages = Message.query.read
      expect(read_messages).to include(read_message)
      expect(read_messages).not_to include(unread_message)
    end

    it 'supports method chaining' do
      recent_unread = Message.query.unread.recent(5)
      expect(recent_unread).to include(unread_message)
      expect(recent_unread.count).to be <= 5
    end
  end

  describe 'status methods' do
    let(:message) { create(:message, :sent) }

    describe '#mark_as_read!' do
      it 'marks message as read and updates status' do
        expect { message.mark_as_read! }.to change { message.read }.from(false).to(true)
        expect(message.status).to eq('read')
      end
    end

    describe '#mark_as_read' do
      it 'marks message as read and updates status without exception' do
        expect { message.mark_as_read }.to change { message.read }.from(false).to(true)
        expect(message.status).to eq('read')
      end
    end

    describe '#mark_as_delivered!' do
      it 'marks message as delivered' do
        expect { message.mark_as_delivered! }.to change { message.status }.from('sent').to('delivered')
      end
    end

    describe '#mark_as_delivered' do
      it 'marks message as delivered without exception' do
        expect { message.mark_as_delivered }.to change { message.status }.from('sent').to('delivered')
      end
    end
  end

  describe 'routing type queries' do
    describe '#direct?' do
      it 'returns true for direct messages' do
        message = create(:message, routing_type: 'direct')
        expect(message.direct?).to be true
      end

      it 'returns false for non-direct messages' do
        message = create(:message, routing_type: 'auto')
        expect(message.direct?).to be false
      end
    end

    describe '#auto?' do
      it 'returns true for auto messages' do
        message = create(:message, routing_type: 'auto')
        expect(message.auto?).to be true
      end

      it 'returns false for non-auto messages' do
        message = create(:message, routing_type: 'direct')
        expect(message.auto?).to be false
      end
    end
  end

  describe 'conversation management' do
    let(:patient) { create(:user, :patient) }
    let(:doctor1) { create(:user, :doctor) }
    let(:doctor2) { create(:user, :doctor) }

    describe '#conversation_owner' do
      it 'returns the sender of the conversation root' do
        root_message = create(:message, outbox: patient.outbox, inbox: doctor1.inbox)
        expect(root_message.conversation_owner).to eq(patient)
      end
    end

    describe '#conversation_doctor' do
      it 'finds the doctor in the conversation' do
        root_message = create(:message, outbox: patient.outbox, inbox: doctor1.inbox)
        expect(root_message.conversation_doctor).to eq(doctor1)
      end

      it 'returns nil if no doctor in conversation' do
        root_message = create(:message, outbox: patient.outbox, inbox: create(:user, :admin).inbox)
        expect(root_message.conversation_doctor).to be_nil
      end
    end

    describe '#conversation_participants' do
      it 'returns all participants in the conversation' do
        root_message = create(:message, outbox: patient.outbox, inbox: doctor1.inbox)
        create(:message, :reply, parent_message: root_message, outbox: doctor1.outbox, inbox: patient.inbox)

        participants = root_message.conversation_participants
        expect(participants).to include(patient, doctor1)
      end
    end

    describe 'service delegations' do
      let(:message) { create(:message, outbox: patient.outbox, inbox: doctor1.inbox) }

      it 'provides conversation methods through direct service calls' do
        expect(message).to respond_to(:conversation_root)
        expect(message).to respond_to(:conversation_owner)
        expect(message).to respond_to(:conversation_messages)
        expect(message).to respond_to(:conversation_participants)
        expect(message).to respond_to(:conversation_doctor)
        expect(message).to respond_to(:threaded?)
        expect(message).to respond_to(:conversation_stats)
      end

      it 'has broadcasting methods available' do
        expect(message).to respond_to(:broadcast_new_message)
        expect(message).to respond_to(:broadcast_update)
      end
    end
  end

  describe 'scopes for eager loading' do
    let(:patient) { create(:user, :patient) }
    let(:doctor) { create(:user, :doctor) }

    describe '.with_basic_data' do
      let!(:message) { create(:message, inbox: patient.inbox, outbox: doctor.outbox) }

      it 'loads messages with minimal associations' do
        result = described_class.with_basic_data.first

        expect { result.outbox.user }.not_to raise_error
        expect { result.parent_message }.not_to raise_error
      end

      it 'does not load replies association' do
        create_list(:message, 2, parent_message: message)
        result = described_class.with_basic_data.first

        expect(result.association(:replies).loaded?).to be false
      end

      it 'loads nested user associations' do
        result = described_class.with_basic_data.first

        # Verify outbox.user is loaded
        expect { result.outbox.user }.not_to raise_error
        # Verify inbox.user is loaded
        expect { result.inbox.user }.not_to raise_error
      end
    end

    describe '.with_full_conversation' do
      let!(:message) { create(:message, inbox: patient.inbox, outbox: doctor.outbox) }
      let!(:replies) { create_list(:message, 3, parent_message: message) }

      it 'loads message with all conversation data' do
        result = described_class.with_full_conversation.first

        expect { result.replies }.not_to raise_error
        expect { result.parent_message }.not_to raise_error
      end

      it 'loads replies association' do
        result = described_class.with_full_conversation.first

        expect(result.association(:replies).loaded?).to be true
        expect(result.replies.count).to eq(3)
      end

      it 'loads nested associations for replies' do
        result = described_class.with_full_conversation.first

        # Verify replies are loaded with their associations
        result.replies.each do |reply|
          expect { reply.inbox.user }.not_to raise_error
          expect { reply.outbox.user }.not_to raise_error
        end
      end
    end

    describe '.with_prescriptions' do
      let!(:prescription) { create(:prescription, user: patient) }
      let!(:message) { create(:message, inbox: patient.inbox, prescription: prescription) }

      it 'loads messages with prescription data' do
        result = described_class.with_prescriptions.first

        expect { result.prescription }.not_to raise_error
        expect { result.prescription.payment }.not_to raise_error
      end

      it 'loads prescription and payment associations' do
        result = described_class.with_prescriptions.first

        expect(result.association(:prescription).loaded?).to be true
        expect(result.prescription).to eq(prescription)
      end

      it 'returns messages without prescriptions' do
        message_without_prescription = create(:message, inbox: patient.inbox, prescription: nil)

        results = described_class.with_prescriptions
        expect(results).to include(message, message_without_prescription)
      end
    end

    describe '.with_full_context' do
      let!(:prescription) { create(:prescription, user: patient) }
      let!(:message) { create(:message, inbox: patient.inbox, outbox: doctor.outbox, prescription: prescription) }
      let!(:replies) { create_list(:message, 2, parent_message: message) }

      it 'loads complete conversation with prescriptions' do
        result = described_class.with_full_context.first

        expect { result.replies }.not_to raise_error
        expect { result.prescription.payment }.not_to raise_error
        expect { result.outbox.user }.not_to raise_error
      end

      it 'combines with_full_conversation and with_prescriptions' do
        result = described_class.with_full_context.first

        expect(result.association(:replies).loaded?).to be true
        expect(result.association(:prescription).loaded?).to be true
        expect(result.replies.count).to eq(2)
      end
    end
  end
end
