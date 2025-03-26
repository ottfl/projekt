import os
import re
import pandas as pd

"""
This script processes log files to extract timer reports from ICON LOG files and save them as CSV files.
It should be called from a directory containing log files or a directory containing directories with log files.

Functions:
- extract_timer_reports(log_file_path): Extracts timer reports from a log file.
- write_tables_to_csv(log_file_path, tables): Writes extracted tables to CSV files.
- find_log_files_and_process(base_folder): Finds log files in a directory and processes them.

Example usage:
    python extract_timer_rep.py

Dependencies:
- pandas
"""

def extract_timer_reports(log_file_path):

    """
    Extracts timer reports from a log file.

    Args:
    - log_file_path: Path to the log file.

    Returns:
    - A list of tables extracted from the log file.
    """

    with open(log_file_path, 'r') as file:
        content = file.readlines()

    # Pattern to identify the start of a timer report
    report_start_pattern = re.compile(r'\s*\d+:\s*-{24,30}\s+')
    report_end_pattern = re.compile(r'\s*\d+:  -+\s+$')

    # Collect all blocks of reports
    reports = []
    current_report = []
    in_report = False

    for line in content:
        if report_start_pattern.match(line) and not in_report:
            in_report = True
            current_report = [line]
        elif in_report:
            current_report.append(line)
            if report_end_pattern.match(line):
                reports.append(current_report)
                in_report = False

    extracted_tables = {}

    for report in reports:
        lines = report[2:-1]  # Skip header lines
        # Extract column names
        columns_line = report[2].strip()
        columns = re.split(r'\s{2,}', columns_line)[1:]  # Avoid empty first

        # Collect rows of the report
        data = []
        for line in lines[5:]:
            if re.match(r'\s*\d+:\s*[a-z]+', line):
                row = re.split(r'\s{2,}', line.strip())[1:]
                if len(row) == len(columns):
                    data.append(row)

        if len(data) == 3:
            table_name = "checkpoints"
        elif len(data) == 2:
            table_name = "io"
        else:
            table_name = "workers"
        
        extracted_tables[table_name] = (columns, data)

    return extracted_tables

def write_tables_to_csv(log_file_path, tables):

    """
    Writes extracted tables to CSV files.

    Args:
    - log_file_path: Path to the log file.
    - tables: A dictionary of tables extracted from the log file.
    """

    base_folder = os.path.dirname(log_file_path)
    for table_name, (col, data) in tables.items():
        df = pd.DataFrame(data, columns=col)
        # Ensure that the table is saved with the appropriate index
        csv_filename = os.path.join(base_folder, f"timer_report_{table_name}.csv")
        df.to_csv(csv_filename, index=False)
        print(f"Saved Table {table_name} to {csv_filename}")

def find_log_files_and_process(base_folder):
    
    """
    Finds log files in a directory and processes them to .csv files.

    Args:
    - base_folder: Path to the directory containing log files.
    """
    
    for dirpath, dirnames, filenames in os.walk(base_folder):
        for filename in filenames:
            if filename == "LOG.o":
                log_file_path = os.path.join(dirpath, filename)
                print(f"Processing: {log_file_path}")
                tables = extract_timer_reports(log_file_path)
                write_tables_to_csv(log_file_path, tables)

# Example usage to start from the current working directory
if __name__ == "__main__":
    base_directory = "."
    find_log_files_and_process(base_directory)