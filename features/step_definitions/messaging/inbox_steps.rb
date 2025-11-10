# frozen_string_literal: true

# Inbox-specific steps for message viewing and reading
# Handles message display, reading, and inbox interactions

Given('I have received a message from a {word}') do |sender_role|
  sender = case sender_role
           when 'doctor'
             @doctor
           when 'patient'
             @patient
           when 'admin'
             @admin
           end

  @received_message = Message.create!(
    body: "Test message from #{sender_role}",
    outbox: sender.outbox,
    inbox: @current_user.inbox,
    routing_type: 'direct',
    status: 'delivered'
  )
  # Set the message variable that existing steps expect
  @message = @received_message
end

When('I open the message') do
  first('.list-group-item').click
end

When('I click to view the message detail') do
  first('.list-group-item').click
end

Then('I should see the message in my inbox') do
  expect(page).to have_css('#inbox-list .list-group-item')
  expect(page).to have_content(@received_message.body) if @received_message
end

Then('I should see the message content') do
  expect(page).to have_content(@received_message.body) if @received_message
end

Then('the message should be marked as read') do
  message_to_check = @received_message || @message
  if message_to_check && Message.exists?(message_to_check.id)
    message_to_check.reload
    expect(message_to_check.read_already?).to be true
  else
    # If message doesn't exist, check that read status is reflected in UI
    expect(page).not_to have_css('.badge-warning')
  end
end
