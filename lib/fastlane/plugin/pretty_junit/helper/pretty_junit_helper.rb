module Fastlane

  module Helper

    class PrettyJunitHelper

      def self.parse_junit_xml(file_path)
        suites = OpenStruct.new(suite:[])
        xml_doc = File.open(file_path) { |f| Nokogiri::XML(f) }

        suite_nodes = xml_doc.xpath("//testsuite")

        suite_nodes.each do |suite_node|
          suite_name = suite_node['name']

          suite = OpenStruct.new(name: suite_name, tests: suite_node['tests'], failures: suite_node['failures'], duration: suite_node['time'], results:[])

          results = OpenStruct.new(skipped:[], failed:[], passed:[])

          failed_nodes = suite_node.xpath("//testcase[failure]")
          skipped_nodes = suite_node.xpath("//testcase[skipped]")
          passed_nodes = suite_node.xpath("//testcase[not(failure) and not(skipped)]")

          passed_nodes.each do |node|
            class_path = node['classname']
            context = parse_context(class_path)
            result = OpenStruct.new(name: node['name'], context: context, class_path: class_path, duration: node['time'])
            results.passed.push result
          end
          skipped_nodes.each do |node|
            class_path = node['classname']
            context = parse_context(class_path)
            result = OpenStruct.new(name: node['name'], context: context, class_path: class_path, duration: node['time'])
            results.skipped.push result
          end
          failed_nodes.each do |node|
            class_path = node['classname']
            context = parse_context(class_path)
            failure = node.xpath('.//failure').first
            result = OpenStruct.new(name: node['name'], context: context, class_path: class_path, duration: node['time'],
                                    fail_message: failure['message'], stack_trace: failure.text)
            results.failed.push result
          end
          suite.results.push results

          suites.suite.push suite
        end

        return suites
      end

      def self.parse_context(class_path) 
          dot_rindex = class_path.rindex('.')
          class_name = dot_rindex ? class_path[dot_rindex+1..-1] : ''
          return class_name.gsub(/\$/, ', ')
      end
    end
  end
end
