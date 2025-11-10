# frozen_string_literal: true

Feature: Patient Communication Journey
  As a patient
  I want to communicate with healthcare providers
  So that I can get the medical support I need

  Background:
    Given the application is running
    And I have test users in the system

  @patient @core
  Scenario: Patient views their messages
    Given I am logged in as a patient
    When I visit my inbox
    Then I should see my inbox page
    When I visit my outbox
    Then I should see my outbox page

  @patient @core @send
  Scenario: Patient sends message to doctor
    Given I am logged in as a patient
    When I compose and send a new message
    Then I should see message sent successfully
    And the message should appear in my outbox

  @patient @core @receive
  Scenario: Patient receives and reads message
    Given I am logged in as a patient
    And I have received a message from a doctor
    When I visit my inbox
    Then I should see the message in my inbox
    When I open the message
    Then I should see the message content
    And the message should be marked as read

  @patient @performance @pagination
  Scenario: View paginated inbox messages with acceptable load time
    Given I am logged in as a patient
    And I have 100 messages in my inbox
    When I visit my inbox
    Then I should see the first 10 messages
    And the page should load within 500ms

  @patient @performance @conversation
  Scenario: View full message conversation with all replies
    Given I am logged in as a patient
    And I have a message with 5 replies
    When I visit my inbox
    And I click to view the message detail
    Then all 5 replies should be loaded and displayed
    And the conversation should load within 1000ms

  @patient @performance @pagination
  Scenario: Paginated outbox messages load efficiently
    Given I am logged in as a patient
    And I have sent 50 messages
    When I visit my outbox
    Then I should see the first 10 messages in order
    And no unnecessary reply data should be loaded
