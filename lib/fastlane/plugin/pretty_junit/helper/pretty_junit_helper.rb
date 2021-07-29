module Fastlane

  module Helper

    class PrettyJunitHelper

      def self.parse_junit_xml(file_path)
        total = OpenStruct.new(suites:[])
        xml_doc = File.open(file_path) { |f| Nokogiri::XML(f) }

        suite_nodes = xml_doc.xpath("//testsuite")

        suite_nodes.each do |suite_node|
          total_suite_name = suite_node['name']
          suite_name = parse_name(suite_node['name'])

          suite = OpenStruct.new(name: suite_name, tests: suite_node['tests'], failures: suite_node['failures'], duration: suite_node['time'], skipped:[], failed:[], passed:[])

          failed_nodes = suite_node.xpath("//testsuite[@name='#{total_suite_name}']//testcase[failure]")
          skipped_nodes = suite_node.xpath("//testsuite[@name='#{total_suite_name}']//testcase[skipped]")
          passed_nodes = suite_node.xpath("//testsuite[@name='#{total_suite_name}']//testcase[not(failure) and not(skipped)]")

          passed_nodes.each do |node|
            class_path = node['classname']
            context = parse_context(class_path)
            result = OpenStruct.new(name: node['name'], context: context, class_path: class_path, duration: node['time'])
            suite.passed.push result
          end
          skipped_nodes.each do |node|
            class_path = node['classname']
            context = parse_context(class_path)
            result = OpenStruct.new(name: node['name'], context: context, class_path: class_path, duration: node['time'])
            suite.skipped.push result
          end
          failed_nodes.each do |node|
            class_path = node['classname']
            context = parse_context(class_path)
            failure = node.xpath('.//failure').first
            webLink = node.xpath('.//webLink').first
            result = OpenStruct.new(name: node['name'], context: context, class_path: class_path, duration: node['time'],
                                    fail_message: failure['message'], stack_trace: failure.text, webLink: webLink.text)
            suite.failed.push result
          end

          total.suites.push suite
        end

        return total
      end

      def self.parse_context(class_path) 
          dot_rindex = class_path.rindex('.')
          class_name = dot_rindex ? class_path[dot_rindex+1..-1] : ''
          return class_name.gsub(/\$/, ', ')
      end

      def self.parse_name(name) 
          index = name.rindex('#')
          name = index ? name[0..index-1] : name
          return name
      end

    end
  end
end
