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

end
