# This script moves the latest CSV file from the Downloads directory to the reflect-dumps directory,
# parses the CSV file to extract questions and answers based on specific patterns, and generates
# a text file that can be imported into Anki. It also updates the .synced_at file with the most
# recent edited_at value from the CSV file.

# Usage:
# 1. Place the CSV files in the Downloads directory.
# 2. Run this script.
# 3. The latest CSV file will be moved to the reflect-dumps directory.
# 4. The script will parse the CSV file and generate a text file for Anki import.
# 5. The .synced_at file will be updated with the most recent edited_at value.

# Writing Notes on Reflect App for Anki Import:
# To ensure your notes on the Reflect app are correctly parsed and imported into Anki, follow these guidelines:

# 1. Tagging Patterns:
#    Use specific tags to identify the type of note. The supported tags are:
#    - #spaced
#    - #reversed
#    - #type
#    - #cloze

# 2. Question and Answer Format:
#    - For #spaced, #reversed, and #type tags, the first bullet point will be treated as the question,
#      and the subsequent bullet points will be treated as answers.
#    - For #cloze tags, only the first bullet point will be used, and it should contain the cloze deletion format
#      (e.g., {{c1::cloze}}).

# 3. Example Note Structure:
#    - Spaced Repetition:
#      <p><a href="https://reflect.app/g/yijisoo/tag/spaced" data-editor-tag="spaced">#spaced</a></p>
#      <p>This is a question</p>
#      <p>This is an answer</p>

#    - Reversed Card:
#      <p><a href="https://reflect.app/g/yijisoo/tag/reversed" data-editor-tag="reversed">#reversed</a></p>
#      <p>This is a question</p>
#      <p>This is an answer</p>

#    - Type in the Answer:
#      <p><a href="https://reflect.app/g/yijisoo/tag/type" data-editor-tag="type">#type</a></p>
#      <p>This is a question</p>
#      <p>This is an answer</p>

#    - Cloze Deletion:
#      <p><a href="https://reflect.app/g/yijisoo/tag/cloze" data-editor-tag="cloze">#cloze</a></p>
#      <p>This is a {{c1::cloze}} card</p>

# 4. Nested Bullet Lists:
#    - For nested bullet lists, the first bullet point will be treated as the question, and the subsequent bullet points
#      will be treated as answers.
#    - Example:
#      <div class="prosemirror-flat-list" data-list-kind="bullet">
#        <p><a href="https://reflect.app/g/yijisoo/tag/spaced" data-editor-tag="spaced">#spaced</a></p>
#        <div class="prosemirror-flat-list" data-list-kind="bullet">
#          <p>Question A</p>
#        </div>
#        <div class="prosemirror-flat-list" data-list-kind="bullet">
#          <p>Answer A</p>
#        </div>
#      </div>

require 'fileutils'
require 'csv'
require 'time'
require 'nokogiri'

# Define the source and destination directories
source_dir = File.expand_path('~/Downloads')
destination_dir = File.join(Dir.pwd, 'reflect-dumps')

puts "Source directory: #{source_dir}"
puts "Destination directory: #{destination_dir}"

def move_latest_file(source_dir, destination_dir)
  begin
    # Ensure the destination directory exists
    Dir.mkdir(destination_dir) unless Dir.exist?(destination_dir)
  rescue => e
    puts "Warning: Could not create destination directory. #{e.message}"
  end

  begin
    # Find the latest modified file matching the pattern
    files = Dir.glob(File.join(source_dir, 'reflect-yijisoo-*.csv'))
    puts "Files found: #{files}"
    file_to_move = files.max_by { |f| File.mtime(f) }
  rescue => e
    puts "Warning: Could not search for files. #{e.message}"
  end

  # Move the file if it exists
  if file_to_move
    puts "Found file to move: #{file_to_move}"
    begin
      FileUtils.mv(file_to_move, destination_dir)
      puts "File moved to #{destination_dir}"
      return File.join(destination_dir, File.basename(file_to_move))
    rescue => e
      puts "Warning: Could not move the file. #{e.message}"
    end
  else
    puts "No file matching the pattern found in #{source_dir}."
  end
  nil
end

def parse_csv_file(csv_file_path)
  # Check the last sync time
  synced_at_file = File.join(Dir.pwd, '.synced_at')
  last_sync_time = if File.exist?(synced_at_file)
                     Time.parse(File.read(synced_at_file).strip)
                   else
                     Time.at(0) # If no sync file, consider the epoch start time
                   end
  puts "Last sync time: #{last_sync_time}"

  # Define patterns
  valid_patterns = [:spaced, :reversed, :type, :cloze]

  anki_import_lines = []
  most_recent_edited_at = last_sync_time

  # Read the CSV file and filter rows
  CSV.foreach(csv_file_path, headers: true) do |row|
    edited_at = row['edited_at'] ? Time.parse(row['edited_at']) : nil
    next unless edited_at && edited_at > last_sync_time

    # Update most recent edited_at
    most_recent_edited_at = edited_at if edited_at > most_recent_edited_at

    # Process the row as it is edited after the last sync time
    # puts "Processing row with id: #{row['id']}"

    document_html = row['document_html']
    if document_html
      # Parse HTML
      doc = Nokogiri::HTML(document_html)

      # Process each pattern
      valid_patterns.each do |name|
        doc.css("a[data-editor-tag='#{name}']").each do |tag|
          parent = tag.parent
          question = nil
          answers = []

          # Search for sub bullets for question and answer
          sub_bullets = parent.css('div.prosemirror-flat-list p')
          if sub_bullets.size >= 2
            question = sub_bullets[0]&.text&.strip
            answers = sub_bullets[1..-1].map { |bullet| bullet.text.strip }
          else
            # Handle original format
            question = parent.next_element&.text&.strip
            answer = parent.next_element&.next_element&.text&.strip
            answers << answer if answer
          end

          if name == :cloze
            cloze_text = question
            if cloze_text && !anki_import_lines.include?("Cloze\tReflect\t#{cloze_text}\t\t")
              puts "Found ##{name} pattern: #{cloze_text}"
              anki_import_lines << "Cloze\tReflect\t#{cloze_text}\t\t"
            end
          elsif question && answers.any?
            answers_text = answers.map { |answer| answer.include?("\n") ? "\"#{answer}\"" : answer }.join("\n")
            puts "Found ##{name} pattern: Question: #{question}, Answer: #{answers_text}"
            case name
            when :spaced
              anki_import_lines << "Basic\tReflect\t#{question}\t#{answers_text}\t"
            when :reversed
              anki_import_lines << "Basic (and reversed card)\tReflect\t#{question}\t#{answers_text}\t"
            when :type
              anki_import_lines << "Basic (type in the answer)\tReflect\t#{question}\t#{answers_text}\t"
            end
          end
        end
      end
    end
  end

  # Write to the Anki import file
  anki_import_file_path = csv_file_path.sub('.csv', '.txt')
  File.open(anki_import_file_path, 'w') do |file|
    file.puts("#separator:tab")
    file.puts("#html:true")
    file.puts("#notetype column:1")
    file.puts("#deck column:2")
    file.puts("#tags column:5")
    anki_import_lines.each { |line| file.puts(line) }
  end
  puts "Anki import file created at: #{anki_import_file_path}"

  # Update the .synced_at file
  File.write(synced_at_file, most_recent_edited_at.iso8601)
  puts "Updated .synced_at file with: #{most_recent_edited_at.iso8601}"
end

# Move the latest file
csv_file_path = move_latest_file(source_dir, destination_dir)

# Parse the CSV file if it was moved
parse_csv_file(csv_file_path) if csv_file_path