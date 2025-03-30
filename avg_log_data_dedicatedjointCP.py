import re
from datetime import datetime
import os

"""
This script processes log files to extract timer reports from ICON LOG files and saves them as txt and CSV files.
Use this for LOG files with "dedicated" or "joint" restart mode.
"""

base_folder = "./messungen/cp/r2b6/12h/n16dedicated"

data = []

# Define the regex pattern to extract timestamps between brackets
pattern_step = r'\[(\d{8} \d{6}\.\d{3})\](?= Time step:)'
# pattern_output = r'(^.*\d+:  Got)' # for IO files
# pattern_output = r'(^.*\d+:  Checkpointing: Got)' # for CP files
pattern_output = r'\[(\d{8} \d{6}\.\d{3})\] :writeRestartInternal: restart: finished:' # for CP with "dedicated" mode 


def compute_average(log_lines):


    """
    Computes various averages from log lines.

    Args:
        log_lines (list of str): List of log lines to process.

    Returns:
        tuple: A tuple containing the following averages:
            - average_duration (float): Average duration between consecutive timestamps.
            - output_size_avg (float): Average output size.
            - time_get_avg (float): Average time to get data.
            - get_mbs_avg (float): Average get throughput in MB/s.
            - time_write_avg (float): Average time to write data.
            - write_mbs_avg (float): Average write throughput in MB/s.
    """
    # Extract all timestamps
    timestamps = []
    output_times = []
    output_count = 0
    for line in log_lines:
        if (match := re.search(pattern_step, line)):
            timestamps.append(match.group(1))
        elif (match := re.search(pattern_output, line)):
            output_times.append(re.findall(r'\d+.?\d*', line))
            output_count += 1

    # Convert timestamps to datetime objects
    time_format = "%Y%m%d %H%M%S.%f"
    datetime_objects = [datetime.strptime(ts, time_format) for ts in timestamps]

    # Calculate time differences between consecutive timestamps
    time_differences = [
        (datetime_objects[i + 1] - datetime_objects[i]).total_seconds()
        for i in range(len(datetime_objects) - 1)
    ]

    # change for "dedicated" restart mode files
    average_duration = sum(time_differences) / len(time_differences)
    output_sizes = [float(x[3]) * 1000 for x in output_times]
    output_size_avg = sum(output_sizes) / len(output_sizes) if len(output_sizes) > 0 else 0
    time_cp = [float(x[4]) for x in output_times]
    time_cp_avg = sum(time_cp) / len(time_cp) if len(time_cp) > 0 else 0
    cp_mbs = [float(x[5]) for x in output_times]
    cp_mbs_avg = sum(cp_mbs) * 1000 / len(cp_mbs) if len(cp_mbs) > 0 else 0

    return (*[average_duration, output_size_avg, time_cp_avg, cp_mbs_avg, sum(output_sizes), output_count],)


for dirpath, dirnames, filenames in os.walk(base_folder):
    for filename in filenames:
        if filename == "LOG.o":
            log_file_path = os.path.join(dirpath, filename)
            last_dir = os.path.basename(dirpath)
            print(f"Processing: {log_file_path}")
            # Read the file
            with open(log_file_path, 'r') as file:
                log_lines = file.readlines()
                data.append([last_dir, *compute_average(log_lines)])

# Sort the data by the number of dedicated PEs
# ONLY USE for dedicated mode
# data.sort(key=lambda x: int(re.match(r'\d+', x[0]).group()))

# Save results to a table in a text file
output_filename = "timestamp_results.txt"
target = os.path.join(base_folder, output_filename)
with open(target, 'w') as output_file:
    output_file.write(f"{'# dedicated PEs':<15}{'avg time step (s)':<17}{'avg CP MB':<17}{'Time CP avg (s)':<17}{'CP MB/s avg':<17}{'Output size sum':<17}{'Output count':<17}\n")
    output_file.write("=" * 110 + "\n")
    
    for i in range(len(data)):
        output_file.write(
            f"{data[i][0]:<15}{data[i][1]:<17.4f}{data[i][2]:<17.4f}{data[i][3]:<17.4f}{data[i][4]:<17.4f}{data[i][5]:<17.4f}{data[i][6]:<17.4f} \n"
        )

# Save results of get mb/s and write mb/s to a csv with #dedicated PEs as index
output_filename = "get_write_speed.csv"
target = os.path.join(base_folder, output_filename)
with open(target, 'w') as output_file:
    output_file.write(f"{'# dedicated PEs'},{'Get MB/s avg'},{'Write MB/s avg'}\n")
    for i in range(len(data)):
        output_file.write(
            f"{data[i][0]},{data[i][4]}\n"
        )





