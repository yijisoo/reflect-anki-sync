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


require 'fileutils'
require 'csv'
require 'time'
require 'nokogiri'

# Define constants. Update this as needed.
# Note: The patterns are case-sensitive.

# Source directory for CSV files
source_path = '~/Downloads'
destination_path = 'reflect-dumps'
anki_deck_name = 'Reflect'

# Define the source and destination directories
source_dir = File.expand_path(source_path)
destination_dir = File.join(Dir.pwd, destination_path)

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

      # Find all relevant <p> elements
      doc.css('div.prosemirror-flat-list div.list-content p').each do |p|
        valid_patterns.each do |pattern|
          if p.text.include?("##{pattern}")
            parent = p.parent
            question = nil
            answers = []

            # Search for sub bullets for question and answer
            sub_bullets = parent.css('div.prosemirror-flat-list div.list-content p')
            if sub_bullets.size >= 2
              question = sub_bullets[0]&.text&.strip
              answers = sub_bullets[1..-1].map { |bullet| bullet.text.strip }
            else
              # Handle original format
              question = parent.next_element&.text&.strip
              answer = parent.next_element&.next_element&.text&.strip
              answers << answer if answer
            end

            if pattern == :cloze
              cloze_text = question
              if cloze_text && !anki_import_lines.include?("Cloze\t#{anki_deck_name}\t#{cloze_text}\t\t")
                puts "Found ##{pattern} pattern: #{cloze_text}"
                anki_import_lines << "Cloze\t#{anki_deck_name}\t#{cloze_text}\t\t"
              end
            elsif question && answers.any?
              answers_text = answers.map { |answer| answer.include?("\n") ? "\"#{answer}\"" : answer }.join("\n")
              puts "Found ##{pattern} pattern: Question: #{question}, Answer: #{answers_text}"
              case pattern
              when :spaced
                anki_import_lines << "Basic\t#{anki_deck_name}\t#{question}\t#{answers_text}\t"
              when :reversed
                anki_import_lines << "Basic (and reversed card)\t#{anki_deck_name}\t#{question}\t#{answers_text}\t"
              when :type
                anki_import_lines << "Basic (type in the answer)\t#{anki_deck_name}\t#{question}\t#{answers_text}\t"
              end
            else
              puts "Pattern ##{pattern} not matched properly for row with id: #{row['id']}"
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