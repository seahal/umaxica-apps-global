# typed: false
# frozen_string_literal: true

html_content = File.read('coverage/rails/index.html')

# Regex to capture file rows
# Example row:
# <tr class="t-file">
#   <td class="strong t-file__name"><a href="..." class="src_link" title="app/...">app/...</a></td>
#   <td class="red strong cell--number t-file__coverage">80.00 %</td>
#   <td class="cell--number">12</td>
#   ...
# </tr>

files = []

# Simple regex to find each file row content
html_content.scan(/<tr class="t-file">.*?<\/tr>/m).each do |row|
  file_name = row.match(/title="([^"]+)"/)[1] rescue next
  coverage_pct = row.match(/t-file__coverage">([\d.]+) %/)[1].to_f rescue next

  # Total lines is the first <td class="cell--number"> after the coverage cell
  # Actually, looking at the HTML:
  # 1st td: file name
  # 2nd td: coverage %
  # 3rd td: Lines

  cells = row.scan(/<td[^>]*>(.*?)<\/td>/m)
  total_lines = cells[2][0].strip.to_i rescue 0

  if file_name.start_with?('app/') && !file_name.start_with?('app/views/')
    files << { name: file_name, coverage: coverage_pct, lines: total_lines }
  end
end

# Sort by coverage ascending, then by lines descending for tie-breaking
sorted_files = files.sort_by { |f| [f[:coverage], -f[:lines]] }

puts "Top 10 files in app/ (excluding app/views) with lowest coverage:"
puts sprintf("%-60s | %-10s | %-10s", "File Name", "Coverage", "Lines")
puts "-" * 85

sorted_files.first(10).each do |f|
  puts sprintf("%-60s | %-9.2f%% | %-10d", f[:name], f[:coverage], f[:lines])
end
