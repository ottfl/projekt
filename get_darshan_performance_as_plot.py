import os
import re
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def extract_io_performance(base_dir, subfolder):
    data = []
    search_path = os.path.join(base_dir, subfolder)
    
    if not os.path.exists(search_path):
        print(f"Path does not exist: {search_path}")
        return
    
    pattern = re.compile(r"<th>I/O performance estimate</th>\s*<td>([0-9]+\.?[0-9]*) MiB/s \(average\)</td>")
    
    for root, _, files in os.walk(search_path):
        for file in files:
            if file.endswith(".html"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    match = pattern.search(content)
                    if match:
                        value = float(match.group(1))
                        rowname = " ".join(os.path.dirname(file_path).split("/")[3:])
                        data.append((rowname, value))
    
    if not data:
        print("No matching data found.")
        return
    
    # you have to switch this because r2b6 path does not include output_interval
    df = pd.DataFrame(data, columns=["File", "I/O Performance (MiB/s)"])
    df["Grid"] = df["File"].apply(lambda x: x.split(" ")[0])
    # df["# Nodes"] = df["File"].apply(lambda x: int(re.findall(r'\d+', x.split(" ")[2])[0]))
    # df["# Nodes"] = df["File"].apply(lambda x: int(re.findall(r'\d+', x.split(" ")[1])[0]))
    # use this if you include restart modes
    df["# Nodes"] = df["File"].apply(lambda x: re.findall(r'n\d+.*', x.split(" ")[2])[0])
    # df["checkpoint_interval"] = df["File"].apply(lambda x: int(re.findall(r'\d+', x.split(" ")[1])[0]))
    # use this if you include restart modes
    df["checkpoint_interval"] = df["File"].apply(lambda x: re.findall(r'\d+\w*', x.split(" ")[1])[0])
    df["# Restart Procs"] = df["File"].apply(lambda x: int(re.findall(r'\d+', x.split(" ")[-1])[0]))
    df.sort_values(by=["Grid", "checkpoint_interval", "# Nodes", "# Restart Procs"], inplace=True)
    # df.sort_values(by=["Grid", "# Nodes", "# IO Procs"], inplace=True)
    df.drop(columns=["File"], inplace=True)

    columns = df.columns.tolist()  # Get the list of columns
    columns.remove('I/O Performance (MiB/s)')            # Remove 'A' from the list
    columns.append('I/O Performance (MiB/s)')             # Append 'A' at the end

    # Reorder the DataFrame
    df = df[columns]
    print(df)
    x_val = np.arange(5)

    plt.plot(x_val, df.loc[(df["checkpoint_interval"] == "12h") & (df["# Nodes"] == "n16dedicated"), "I/O Performance (MiB/s)"], label="16 Node dedicated multifile", color="red", linestyle='-')
    plt.plot(x_val, df.loc[(df["checkpoint_interval"] == "12h") & (df["# Nodes"] == "n16"), "I/O Performance (MiB/s)"], label="16 Node async", color="green", linestyle='-')
    plt.plot(x_val, df.loc[(df["checkpoint_interval"] == "12h") & (df["# Nodes"] == "n1"), "I/O Performance (MiB/s)"], label="1 Node async", color="turquoise", linestyle='-')
    plt.plot(x_val, df.loc[(df["checkpoint_interval"] == "12h") & (df["# Nodes"] == "n2"), "I/O Performance (MiB/s)"], label="2 Node async", color="orange", linestyle='-')
    plt.plot(0, df.loc[(df["checkpoint_interval"] == "12h") & (df["# Nodes"] == "n16joint"), "I/O Performance (MiB/s)"], label="16 Node joint multifile", marker="o", color="blue", linestyle='-')
    x_labels = df.loc[(df["checkpoint_interval"] == "12h") & (df["# Nodes"] == "n1"), "# Restart Procs"].to_list()
    plt.xticks(x_val, x_labels, rotation=45)
    print(x_labels)
    plt.xlabel("# Restart Procs")
    plt.ylabel("I/O Performance (MiB/s)")
    plt.title("I/O Performance according to Darshan"
              "\nGrid: 40km, 12h Checkpointintervall")
    plt.legend()

    plt.show()

    # Output the table to a file
    # output_path = os.path.join(base_dir, "io_performance_table.png")
    # plt.savefig(output_path, bbox_inches='tight', dpi=300)
    # print(f"Table saved as {output_path}")

# Example usage
base_dir = "./messungen/"  # Change this to your base directory
subfolder = "cp/r2b6/"  # Change this to your target subfolder
extract_io_performance(base_dir, subfolder)