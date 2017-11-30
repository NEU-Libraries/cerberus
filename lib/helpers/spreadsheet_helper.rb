module SpreadsheetHelper

  def load_spreadsheet(sheet_location)
    if sheet_location =~ /\b.xlsx$\b/
      worksheet = Roo::Excelx.new(sheet_location)
    else
      # TODO: Notify that only xslx is currently supported
    end
    worksheet.default_sheet = worksheet.sheets.first #Sets to the first sheet in the workbook
    return worksheet
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length do |row_pos|
      case header_row[row_pos]
        when column_identifier
          return strip_value(row_value[row_pos])
      end
    end
    return nil
  end

  def validate_spreadsheet(spreadsheet_location)
    spreadsheet = load_spreadsheet(spreadsheet_location)

    results = []

    header_regex = ['What is the handle for the digitized object?',
    'What is your name?',
    'What is the PID for the digitized object?',
    'File Name',
    'File Name - Poster',
    'Identifier \d',
    'Identifier Type \d',
    'Archives Identifier',
    'Is this a supplied title?',
    'Title Initial Article',
    'Title',
    'Subtitle',
    'Alternate Title \d',
    'Alternate Title \d Initial Article',
    'Alternate Title \d Subtitle',
    'Creator 1 Name - Primary Creator',
    'Creator 1 Authority',
    'Creator 1 Name Type',
    'Creator 1 Role',
    'Creator 1 Affiliation',
    'Creator \d Name',
    'Creator \d Authority',
    'Creator \d Name Type',
    'Creator \d Role',
    'Creator \d Affiliation',
    'Type of Resource',
    'Genre \d',
    'Genre Authority \d',
    'Date Created',
    'Date Created - End Date',
    'Date Created - Is this date approximate, inferred, or questionable?',
    'Copyright Date',
    'Date Issued \(Published\)',
    'Publisher Name',
    'Place of Publication',
    'Edition',
    'Issuance',
    'Frequency',
    'Frequency Authority',
    'Reformatting Quality',
    'Extent',
    'Digital Origin',
    'Language \d',
    'Abstract \d',
    'Table of Contents',
    'Access Condition : Restriction on access \d',
    'Access Condition : Use and Reproduction \d',
    'Note \d',
    'Note \d Attribute',
    'Original Title',
    'What is the physical location for this object?',
    'What is the original identifier?',
    'Collection Title',
    'Series Title',
    'Topical Subject Heading \d',
    'Topical Subject Heading Authority \d',
    'Name Subject Heading \d',
    'Name Subject Heading Authority \d',
    'Name Subject Heading Name Type \d',
    'Name Subject Heading Affiliation \d',
    'Geographic Subject Heading \d',
    'Geographic Subject Heading Authority \d',
    'Temporal Subject Heading \d',
    'Temporal Subject Heading End Date \d',
    'Temporal Subject Heading Qualifier \d',
    'Title Subject \d',
    'Title Subject Initial Article \d',
    'Title Subject Subtitle \d',
    'Title Subject Alternate Title \d',
    'Title Subject Alternate Title Initial Article \d',
    'Title Subject Alternate Title Subtitle \d',
    'Geographic Code Subject Heading \d',
    'Geographic Code Subject Heading Authority \d',
    'Genre Subject \d',
    'Genre Subject Authority \d',
    'Cartographics Subject Coordinates \d',
    'Cartographics Subject Scale \d',
    'Cartographics Subject Projection \d',
    'Cartographics Subject Authority \d']

    # Empty spreadsheet check
    if spreadsheet.first_row.nil?
      results << {:position=>"", :status=>"Error", :issue=>"Your upload could not be processed because the submitted .zip file contains an empty spreadsheet.", :original_value=>"", :suggested_value=>""}
    end

    # Column heading regex check for spelling issues and whitespace
    header_position = 1
    header_row = spreadsheet.row(header_position)

    # Title and keyword check
    title_found = false
    keyword_found = false
    any_found = false

    0.upto header_row.length-1 do |row_pos|
      result = nil
      column_alpha = num_to_s26(row_pos + 1)

      if !header_row[row_pos].blank?
        true_val = header_row[row_pos]
        val_num = true_val[/\d+/]
        val = header_row[row_pos].downcase.strip
        header_regex.each do |rgx_str|
          rgx = Regexp.new '^' + rgx_str.downcase
          result = val.match(rgx)
          break if !result.blank?
        end
        if result.blank?
          if !val.match(/\s\s/).blank?
            # Double whitespace error!
            # errors << "Column #{column_alpha} has double whitespace. Loader will not match with this string - #{true_val}"
            results << {:position=>"Column #{column_alpha}", :status=>"Error", :issue=>"Double whitespace found", :original_value=>"#{true_val}", :suggested_value=>""}
          else
            # trim, remove numbers, tokenize, and compare to expected headers with common words and low Damerau Levenshtein distance
            user_val = true_val.tr("0-9", "").downcase.strip
            tokens = user_val.split(/\s/)

            # loop - if any > 1 tokens found, save result as highest tokens found
            token_count = 0
            highest_match = nil
            distance = 0

            header_regex.each do |str|
              header_tokens = str.gsub('\d','').downcase.strip.split(/\s/)
              token_match_count = (tokens & header_tokens).length

              if token_match_count > token_count
                highest_match = str.gsub('\d', val_num ? val_num : '#number').strip #substitute number if available
                token_count = token_match_count
                distance = DamerauLevenshtein.distance(user_val, str.gsub('\d', '').downcase.strip)
              end
            end

            if !highest_match.blank? && distance < 10
              # Try and give suggestion
              results << {:position=>"Column #{column_alpha}", :status=>"Warning", :issue=>"Not found in expected values", :original_value=>"#{true_val}", :suggested_value=>"#{highest_match}"}
            else
              # No matching header for spreadsheet value!
              results << {:position=>"Column #{column_alpha}", :status=>"Warning", :issue=>"Not found in expected values", :original_value=>"#{true_val}", :suggested_value=>""}
            end
          end
        else
          # Match found
          any_found = true

          if val == "title"
            title_found = true
          end
          if val.include? "subject"
            keyword_found = true
          end
        end
      end
    end

    if !any_found
      # error
      results << {:position=>"", :status=>"Error", :issue=>"No column headers matched any expected values", :original_value=>"", :suggested_value=>""}
    end

    if !title_found
      # error
      results << {:position=>"", :status=>"Error", :issue=>"No title metadata found", :original_value=>"", :suggested_value=>""}
    end

    if !keyword_found
      # error
      results << {:position=>"", :status=>"Error", :issue=>"No keyword metadata found", :original_value=>"", :suggested_value=>""}
    end

    # Presume existing_files is false until we see a pid or file name
    # This allows us to ignore blank pid/file name columns for flexability
    existing_files = false
    file_and_pid_errors = []

    # Filename and PID value checks
    start = header_position + 1
    end_row = spreadsheet.last_row.to_i
    (start..end_row).each do |x|
      row = spreadsheet.row(x)
      if row.present? && header_row.present?
        begin
          row_results = Hash.new
          row_results["file_name"] = find_in_row(header_row, row, 'File Name')
          row_results["pid"] = find_in_row(header_row, row, 'What is the PID for the digitized object?')

          if row_results["file_name"].blank? && !row_results["pid"].blank?
            existing_files = true
          end

          if row_results["file_name"].blank? && row_results["pid"].blank? # Must have either file names or PIDs - new or existing
            file_and_pid_errors << {:position=>"Row #{x}", :status=>"Error", :issue=>"Missing file names or PIDs", :original_value=>"", :suggested_value=>""}
          elsif !row_results["pid"].blank? && !row_results["pid"].start_with?("neu:") # Incorrectly formatted PIDs
            file_and_pid_errors << {:position=>"Row #{x}", :status=>"Error", :issue=>"PID is incorrectly formatted", :original_value=>"", :suggested_value=>""}
          elsif !existing_files && !row_results["handle"].blank? # New files shouldn't have handles
            file_and_pid_errors << {:position=>"Row #{x}", :status=>"Error", :issue=>"New files don't have preexisting handles", :original_value=>"", :suggested_value=>""}
          end
        rescue Exception
        end
      end
    end

    # add file and pid errors to total
    results.concat file_and_pid_errors

    return results

  end

  def num_to_s26(num)
    # Convert column numbers to excel Alpha values
    alpha26 = ("a".."z").to_a
    return "" if num < 1
    s, q = "", num
    loop do
      q, r = (q - 1).divmod(26)
      s.prepend(alpha26[r])
      break if q.zero?
    end
    s.upcase
  end

end
