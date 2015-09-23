# encoding: utf-8
# rubocop:disable all
require 'test_helper'

class EmailPostmasterTest < ActiveSupport::TestCase
  test 'process with postmaster filter' do
    group1 = Group.create_if_not_exists(
      name: 'Test Group1',
      created_by_id: 1,
      updated_by_id: 1,
    )
    group2 = Group.create_if_not_exists(
      name: 'Test Group2',
      created_by_id: 1,
      updated_by_id: 1,
    )
    PostmasterFilter.destroy_all
    PostmasterFilter.create(
      name: 'not used',
      match: {
        from: {
          operator: 'contains',
          value: 'nobody@example.com',
        },
      },
      perform: {
        'X-Zammad-Ticket-priority' => {
          value: '3 high',
        },
      },
      channel: 'email',
      active: true,
      created_by_id: 1,
      updated_by_id: 1,
    )
    PostmasterFilter.create(
      name: 'used',
      match: {
        from: {
          operator: 'contains',
          value: 'me@example.com',
        },
      },
      perform: {
        'X-Zammad-Ticket-group_id' => {
          value: group1.id,
        },
        'x-Zammad-Article-Internal' => {
          value: true,
        },
      },
      channel: 'email',
      active: true,
      created_by_id: 1,
      updated_by_id: 1,
    )
    PostmasterFilter.create(
      name: 'used x-any-recipient',
      match: {
        'x-any-recipient' => {
          operator: 'contains',
          value: 'any@example.com',
        },
      },
      perform: {
        'X-Zammad-Ticket-group_id' => {
          value: group2.id,
        },
        'x-Zammad-Article-Internal' => {
          value: true,
        },
      },
      channel: 'email',
      active: true,
      created_by_id: 1,
      updated_by_id: 1,
    )

    data = 'From: me@example.com
To: customer@example.com
Subject: some subject

Some Text'

    parser = Channel::EmailParser.new
    ticket, article, user = parser.process( { trusted: false }, data )
    assert_equal('Test Group1', ticket.group.name)
    assert_equal('2 normal', ticket.priority.name)
    assert_equal('some subject', ticket.title)

    assert_equal('Customer', article.sender.name)
    assert_equal('email', article.type.name)
    assert_equal(true, article.internal)

    data = 'From: Some Body <somebody@example.com>
To: Bob <bod@example.com>
Cc: any@example.com
Subject: some subject

Some Text'

    parser = Channel::EmailParser.new
    ticket, article, user = parser.process( { trusted: false }, data )

    assert_equal('Test Group2', ticket.group.name)
    assert_equal('2 normal', ticket.priority.name)
    assert_equal('some subject', ticket.title)

    assert_equal('Customer', article.sender.name)
    assert_equal('email', article.type.name)
    assert_equal(true, article.internal)


    PostmasterFilter.create(
      name: 'used x-any-recipient',
      match: {
        'x-any-recipient' => {
          operator: 'contains not',
          value: 'any_not@example.com',
        },
      },
      perform: {
        'X-Zammad-Ticket-group_id' => {
          value: group2.id,
        },
        'X-Zammad-Ticket-priority_id' => {
          value: '1',
        },
        'x-Zammad-Article-Internal' => {
          value: 'false',
        },
      },
      channel: 'email',
      active: true,
      created_by_id: 1,
      updated_by_id: 1,
    )

    data = 'From: Some Body <somebody@example.com>
To: Bob <bod@example.com>
Cc: any@example.com
Subject: some subject2

Some Text'

    parser = Channel::EmailParser.new
    ticket, article, user = parser.process( { trusted: false }, data )

    assert_equal('Test Group2', ticket.group.name)
    assert_equal('1 low', ticket.priority.name)
    assert_equal('some subject2', ticket.title)

    assert_equal('Customer', article.sender.name)
    assert_equal('email', article.type.name)
    assert_equal(false, article.internal)

    PostmasterFilter.destroy_all

    PostmasterFilter.create(
      name: 'used - empty selector',
      match: {
        from: {
          operator: 'contains',
          value: '',
        },
      },
      perform: {
        'X-Zammad-Ticket-group_id' => {
          value: group2.id,
        },
        'X-Zammad-Ticket-priority_id' => {
          value: '1',
        },
        'x-Zammad-Article-Internal' => {
          value: true,
        },
      },
      channel: 'email',
      active: true,
      created_by_id: 1,
      updated_by_id: 1,
    )

    data = 'From: Some Body <somebody@example.com>
To: Bob <bod@example.com>
Cc: any@example.com
Subject: some subject - no selector

Some Text'

    parser = Channel::EmailParser.new
    ticket, article, user = parser.process( { trusted: false }, data )

    assert_equal('Users', ticket.group.name)
    assert_equal('2 normal', ticket.priority.name)
    assert_equal('some subject - no selector', ticket.title)

    assert_equal('Customer', article.sender.name)
    assert_equal('email', article.type.name)
    assert_equal(false, article.internal)

    PostmasterFilter.destroy_all
  end

end