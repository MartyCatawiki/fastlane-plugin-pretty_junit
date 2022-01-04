require 'terminal-table'
require 'nokogiri'
require 'colorize'

module Fastlane

  module Actions

    class PrettyJunitAction < Action

      def self.run(params)
        file_pattern = params[:file_pattern]
        UI.message "Searching for JUnit XML files with pattern \"#{file_pattern}\""

        matching_files = Dir.glob(file_pattern)
        UI.user_error! "No files found! Did your project compile?" unless matching_files.any? 
        UI.message "Processing files: #{matching_files.join(", ")}"

        all_results = []
        total = OpenStruct.new(suites:[])

        headings = ['', 'Context', 'Test', 'Duration']
        table = Terminal::Table.new(title: "Test Results", headings: headings) do |t|

          matching_files.each do |file|

            results = nil
            begin
              results = Helper::PrettyJunitHelper.parse_junit_xml(file)
              # all_results << results
            rescue Exception => ex
              UI.crash! "An error occurred while trying to parse \"#{file}\": #{ex}"
            end

            results.suites.each do |suite|
              # foundAlready = false
              # total.suites.each do |existingSuite|
              #   if existingSuite.name == suite.name
              #     foundAlready = true
              #   end  
              #   existingSuite.tests += suite.tests
              #   existingSuite.failures += suite.failures
              #   existingSuite.duration += suite.duration
              # end  
              # if !foundAlready 
              #   total.suites.push suite
              # end  
              total.suites.push suite

              t.add_row ['📱', suite.context, suite.name, suite.duration]

              suite.failed.each do |result|
                t.add_row ['🔥', result.context.red, result.name.red, result.duration.red]
              end
              suite.passed.each do |result|
                t.add_row ['✅', result.context.green, result.name.green, result.duration.green]
              end
              suite.skipped.each do |result|
                t.add_row ['❔', result.context, result.name, result.duration]
              end

            end

          end
        end

        UI.message "\n#{table}\n"

        resultsDictionary = {}
        failures = 0

        #all_results << total

        total.suites.each do |suite|
          all_failed = suite.failed#map{ |r| r.failed }.flatten
          all_failed.each do |failed|
            UI.error "Failed #{failed.class_path}.#{failed.name} with message: \n#{failed.fail_message}\nStack trace:\n#{failed.stack_trace}\n"
          end

          all_failed.each do |failed|
            UI.error "Failed #{failed.class_path}.#{failed.name} with message:\n\n#{failed.fail_message}\nSee above for stack trace.\n"
          end

          failed_count = suite.failed.length #suite.inject(0) { |sum, r| sum + r.failed.length }
          skipped_count = suite.skipped.length #suite.inject(0) { |sum, r| sum + r.skipped.length }
          passed_count = suite.passed.length #suite.inject(0) { |sum, r| sum + r.passed.length }

          messages = []
          messages << "#{passed_count} passed".green
          messages << "#{skipped_count} skipped"
          messages << "#{failed_count} failed".red
          test_counts = "#{messages.join(', ')}"

          if failed_count == 0
            message = "All tests passed!".green
            UI.message "#{suite.name}: #{message} #{test_counts}"
          else
            message = "You have failing tests!".red
            #UI.user_error! "#{message} #{test_counts}"
            UI.message "#{suite.name}: #{message} #{test_counts}"
          end

          # For the Slack 
          failures += failed_count
          testCaseSummary = ""

          suite.failed.each do |result|
            #testCaseSummary += "🔥 <#{result.webLink}|#{result.name}>\n"
            testCaseSummary += "🔥 #{result.name}\n"
          end
          # suite.passed.each do |result|
          #   testCaseSummary += "✅ #{result.name}\n"
          # end
          # suite.skipped.each do |result|
          #   testCaseSummary += "❔ #{result.name}\n"
          # end

          totalNrOfTest = suite.tests.to_i - skipped_count
          totalNrOfSuccessfulTest = passed_count

          testProcessDurationSeconds = suite.duration.to_i || 0
          msgTestTime = "⏳ Test: #{testProcessDurationSeconds.to_i / 60} min #{testProcessDurationSeconds.to_i % 60} sec"

          totalTestRuns = "Tests run: #{totalNrOfSuccessfulTest}/#{totalNrOfTest}"
          if totalNrOfTest > 0 && totalNrOfSuccessfulTest == totalNrOfTest
            totalTestRuns = "✅ #{totalTestRuns}, *100% success*."
          else
            percentage = totalNrOfSuccessfulTest * 100 / totalNrOfTest
            totalTestRuns = ":warning: #{totalTestRuns}, *#{percentage}% success*."
          end  

          resultsDictionary["#{suite.name}"] = "#{totalTestRuns}\n#{msgTestTime}.\n#{testCaseSummary}"
        end
        UI.message resultsDictionary
        return (failures == 0), resultsDictionary
      end

      def self.description
        "Pretty JUnit test results for your projects."
      end

      def self.details
        "Pretty prints JUnit test results for your projects. You should make sure that the previous test results are deleted before running the gradle action, and that the grade action does not fail the lane on test failure. To delete the files, you can use the delete_files plugin and pass in the same file pattern that you pass to this action. To prevent the gradle action from failing on test failure, you can hack around it by appending '|| true' to the end of the 'flags' argument."
      end

      def self.authors
        ["Gary Johnson"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :file_pattern,
                                       description: "Glob file pattern to search for junit-style xml files")
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
