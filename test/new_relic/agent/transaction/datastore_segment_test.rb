# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','test_helper'))

require 'new_relic/agent/transaction/datastore_segment'

module NewRelic
  module Agent
    class Transaction
      class DatastoreSegmentTest < Minitest::Test
        def setup
          freeze_time
        end

        def teardown
          NewRelic::Agent.drop_buffered_data
        end

        def test_datastore_segment_name_with_collection
          segment = DatastoreSegment.new "SQLite", "insert", "Blog"
          assert_equal "Datastore/statement/SQLite/Blog/insert", segment.name
        end

        def test_datastore_segment_name_with_operation
          segment = DatastoreSegment.new "SQLite", "select"
          assert_equal "Datastore/operation/SQLite/select", segment.name
        end

        def test_segment_records_expected_metrics
          Transaction.stubs(:recording_web_transaction?).returns(true)

          segment = DatastoreSegment.new "SQLite", "insert", "Blog"
          segment.start
          advance_time 1
          segment.finish

          assert_metrics_recorded [
            "Datastore/statement/SQLite/Blog/insert",
            "Datastore/operation/SQLite/insert",
            "Datastore/SQLite/allWeb",
            "Datastore/SQLite/all",
            "Datastore/allWeb",
            "Datastore/all"
          ]
        end

        def test_segment_records_expected_metrics_without_collection
          Transaction.stubs(:recording_web_transaction?).returns(true)

          segment = DatastoreSegment.new "SQLite", "select"
          segment.start
          advance_time 1
          segment.finish

          assert_metrics_recorded [
            "Datastore/operation/SQLite/select",
            "Datastore/SQLite/allWeb",
            "Datastore/SQLite/all",
            "Datastore/allWeb",
            "Datastore/all"
          ]
        end

        def test_segment_records_expected_metrics_with_instance_identifier
          Transaction.stubs(:recording_web_transaction?).returns(true)

          segment = DatastoreSegment.new "SQLite", "select", nil, "localhost:1337807"
          segment.start
          advance_time 1
          segment.finish

          assert_metrics_recorded [
            "Datastore/instance/SQLite/localhost:1337807",
            "Datastore/operation/SQLite/select",
            "Datastore/SQLite/allWeb",
            "Datastore/SQLite/all",
            "Datastore/allWeb",
            "Datastore/all"
          ]
        end

        def test_add_instance_identifier_segment_parameter
          segment = nil

          in_transaction do
            segment = NewRelic::Agent::Transaction.start_datastore_segment "SQLite", "select", nil, "localhost:1337807"
            advance_time 1
            segment.finish
          end

          sample = NewRelic::Agent.agent.transaction_sampler.last_sample
          node = find_node_with_name(sample, segment.name)

          assert_equal node.params[:instance], "localhost:1337807"
        end

        def test_add_database_name_segment_parameter
          segment = nil

          in_transaction do
            segment = NewRelic::Agent::Transaction.start_datastore_segment "SQLite", "select", nil, nil, "jonan.gummy_planet"
            advance_time 1
            segment.finish
          end

          sample = NewRelic::Agent.agent.transaction_sampler.last_sample
          node = find_node_with_name(sample, segment.name)

          assert_equal node.params[:database_name], "jonan.gummy_planet"
        end

        def test_notice_sql
          in_transaction do
            segment = NewRelic::Agent::Transaction.start_datastore_segment "SQLite", "select"
            segment.notice_sql "select * from blogs"
            advance_time 2.0
            Agent.instance.transaction_sampler.expects(:notice_sql_statement).with(segment.sql_statement, 2.0)
            Agent.instance.sql_sampler.expects(:notice_sql_statement) do |statement, name, duration|
              assert_equal segment.sql_statement.sql, statement.sql_statement
              assert_equal segment.name, name
              assert_equal duration, 2.0
            end
            segment.finish
          end
        end

        def test_notice_sql_creates_database_statement_with_identifier
          in_transaction do
            segment = NewRelic::Agent::Transaction.start_datastore_segment "SQLite", "select", nil, "jonan.gummy_planet"
            segment.notice_sql "select * from blogs"
            segment.finish

            assert_equal "jonan.gummy_planet", segment.sql_statement.instance_identifier
          end
        end

        def test_notice_sql_creates_database_statement_with_database_name
          in_transaction do
            segment = NewRelic::Agent::Transaction.start_datastore_segment "SQLite", "select", nil, nil, "pizza_cube"
            segment.notice_sql "select * from blogs"
            segment.finish

            assert_equal "pizza_cube", segment.sql_statement.database_name
          end
        end

        def test_internal_notice_sql
          explainer = stub(:explainer)
          in_transaction do
            segment = NewRelic::Agent::Transaction.start_datastore_segment "SQLite", "select"
            segment._notice_sql "select * from blogs", {:adapter => :sqlite}, explainer
            advance_time 2.0
            Agent.instance.transaction_sampler.expects(:notice_sql_statement).with(segment.sql_statement, 2.0)
            Agent.instance.sql_sampler.expects(:notice_sql_statement) do |statement, name, duration|
              assert_equal segment.sql_statement.sql, statement.sql_statement
              assert_equal segment.name, name
              assert_equal duration, 2.0
            end
            segment.finish
          end
        end
      end
    end
  end
end
