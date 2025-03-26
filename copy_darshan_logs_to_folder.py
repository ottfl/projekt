import os
import re
from datetime import datetime
import shutil

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

darshan_log_dir = "/home/k/k203180/darshan_logs"

def extract_job_end_time_from_log(log_file_path):

    """
    Extracts end time from a log file.

    Args:
    - log_file_path: Path to the log file.

    Returns:
    - The end time of the job in datetime format.
    """

    with open(log_file_path, 'r') as file:
        content = file.readlines()

    # Pattern to identify the start of a timer report
    time_pattern = re.compile(r'^.{3} .{3}\s+\d{1,2} \d{2}:\d{2}:\d{2}')
    in_report = False

    try:
        for line in content:
            if time_pattern.match(line):
                if not in_report:
                    in_report = True
                else:
                    print(line)
                    date_string_without_tz = line.replace("CET", "").strip()

                    # Define the format of the original date string without the timezone
                    format_string = "%a %b %d %H:%M:%S %Y"

                    # Parse the date string into a datetime object
                    dt = datetime.strptime(date_string_without_tz, format_string)
                    return dt
    except Exception as e:
        print(f"Error extracting end time: {e}")


def get_darshan_log(end_time):

    """
    Finds the Darshan log file that matches the end time.

    Args:
    - end_time: The end time of the job.

    Returns:
    - The path to the Darshan log file.
    """

    
    # Get the start and end of the minute to match
    start_of_minute = end_time.replace(second=0, microsecond=0)
    end_of_minute = start_of_minute.replace(second=59, microsecond=999999)

    # Iterate through the folder
    for filename in os.listdir(darshan_log_dir):
        file_path = os.path.join(darshan_log_dir, filename)
        
        # Get the last modified time of the file
        last_modified_time = datetime.fromtimestamp(os.path.getmtime(file_path))
        
        # Check if the last modified time is within the same minute
        if start_of_minute <= last_modified_time <= end_of_minute:
            return file_path


def copy_darshan_logs_to_folder(base_folder):
    
    """
    Copies Darshan log files to the folder containing the ICON log files.

    Args:
    - base_folder: The path to the base folder containing the ICON log files.
    """
    
    for dirpath, dirnames, filenames in os.walk(base_folder):
        for filename in filenames:
            if filename == "LOG.o":
                log_file_path = os.path.join(dirpath, filename)
                print(f"Processing: {log_file_path}")
                end_time = extract_job_end_time_from_log(log_file_path)
                log_path = get_darshan_log(end_time)
                if log_path == None:
                    log_path = get_darshan_log(end_time.replace(minute=end_time.minute - 1))
                try:
                    shutil.copy(log_path, dirpath)
                except Exception as e:
                    print(f"Error copying Darshan log: {e}")

# Example usage to start from the current working directory
if __name__ == "__main__":
    base_directory = "."
    copy_darshan_logs_to_folder(base_directory)