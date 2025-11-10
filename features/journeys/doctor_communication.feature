# frozen_string_literal: true

Feature: Doctor Communication Journey
  As a doctor
  I want to communicate with patients
  So that I can provide medical care and guidance

  Background:
    Given the application is running
    And I have test users in the system

  @doctor @core
  Scenario: Doctor views patient messages
    Given I am logged in as a doctor
    When I visit my inbox
    Then I should see my inbox page

  @doctor @core @reply
  Scenario: Doctor replies to patient message
    Given I am logged in as a doctor
    And I have received a message from a patient
    When I visit my inbox
    And I open the message
    And I reply to the message with "Thank you for your message"
    Then I should see message sent successfully
    And the reply should appear in my outbox

  @doctor @performance @pagination
  Scenario: Doctor views paginated inbox with many messages
    Given I am logged in as a doctor
    And I have received 75 messages from patients
    When I visit my inbox
    Then I should see the first 10 messages
    And the page should load efficiently without loading all replies

  @doctor @performance @conversation
  Scenario: Doctor views detailed conversation with patient
    Given I am logged in as a doctor
    And I have an ongoing conversation with 8 message exchanges
    When I visit my inbox
    And I click to view the message detail
    Then all messages in the conversation should be loaded
    And I can see all replies in the conversation thread
