# +---------------------------------------------+
# | Name: Irmin graph generator                 |
# | Author: Ioana Cristescu <ioana@tarides.com> |
# | Version: 20220513                           |
# +---------------------------------------------+

import json
import argparse
import os.path
import pandas as pd
import seaborn as sn
import matplotlib.pyplot as plt
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument(
    "-p", "--path", action="append",
    help="list of path to summaries in json format, separated by comma",
    required=True)
parser.add_argument(
    "-d", "--dest", type=str,
    help="Specify the destination for graphs",
    default="./",
    required=False
)
args = parser.parse_args()
export_path = args.dest

def load_json(paths):
    print("paths", paths)
    raw_path = [path.strip() for path in paths]
    version = [os.path.splitext(os.path.basename(path))[0].split("-")
               for path in raw_path]
    new_version = []
    for v in version:
        if len(v) == 2:
            new_version.append(v[0] + " " + v[1])
        elif len(v) == 3:
            new_version.append(v[0] + " " + v[1] + "\nindexing:" + v[2])
    js = dict()
    for i, path in enumerate(raw_path):
        print("i path", i, path)
        js[new_version[i]] = json.loads(open(path).read())
    return js


def create_bar_plot(df, data, file="default.png", title="",
                    xlabel="", ylabel="", color="LightGreen"):
    print("== Start produce a new bar plot ==")
    print("[I] Show data structure:")
    print(df)
    plt.close("all")
    sn.barplot(data=df, x="version", y=data,
               ci=None, color=color)
    plt.xticks(rotation=50)
    for i, v in enumerate(df['version']):
        plt.text(i, df[data][i] // 2 + 0.3, df[data][i], ha='center')
    if title != "":
        plt.title(title)
    plt.xlabel(xlabel)
    if ylabel != "":
        plt.ylabel(ylabel)
    plt.tight_layout()
    print("[+] Plot data")
    plt.savefig(os.path.join(export_path, file), dpi=150)
    print("[+] Save plot in {}".format(file))
    print("====================")


def create_total_plot(df, file="default.png", title="", v1="v1", v2="v2",
                      ylabel=""):
    print("== Start produce a new cat plot ==")
    print("[I] Show data structure:")
    print(df)
    plt.close("all")
    N = len(df['version'])
    ind = np.arange(N)
    width = 0.25
    b1 = plt.bar(ind, df[v1], width, color="LightBlue")
    b2 = plt.bar(ind + width, df[v2], width, color="LightCyan")
    b3 = plt.bar(ind + width * 2, df['total'], width, color="MediumAquaMarine")
    if title != "":
        plt.title(title)
    if ylabel != "":
        plt.ylabel(ylabel)
    plt.xticks(ind+width, df['version'])
    plt.legend((b1, b2, b3), (v1, v2, 'total'))
    plt.xticks(rotation=50)
    plt.tight_layout()
    print("[+] Plot data")
    plt.savefig(os.path.join(export_path, file), dpi=150)
    print("[+] Save plot in {}".format(file))
    print("====================")


def create_multiline_plot(xdata, ydata, file="default.png",
                          title="", xlabel="", ylabel=""):
    print("== Start produce a multiline plot ==")
    plt.close("all")
    for k in ydata.keys():
        plt.plot(xdata, ydata[k], label=k)
    if title != "":
        plt.title(title)
    if xlabel != "":
        plt.xlabel(xlabel)
    if ylabel != "":
        plt.ylabel(ylabel)
    plt.legend()
    plt.tight_layout()
    print("[+] Plot data")
    plt.savefig(os.path.join(export_path, file), dpi=150)
    print("[+] Save plot in {}".format(file))
    print("====================")


js = load_json(args.path)
version = list(js.keys())

# CPU time plot {{
cpu_df = {
    'version': version,
    'elapsed_wall': [j['elapsed_wall'] for j in list(js.values())]
}
cpu_df = pd.DataFrame(cpu_df)
cpu_df['elapsed_wall'] = cpu_df['elapsed_wall'].apply(
    lambda x: round(x / 3600, 2))
create_bar_plot(cpu_df, 'elapsed_wall', file='cpu.png',
                title="Elapsed wall CPU Time",
                xlabel="", ylabel="CPU Time in hour(s)")
# }}


# bytes read_write plot {{
read = [round(j['index']['bytes_read']['value_after_commit']
        ['max_value'][0] / 1_000_000_000, 2) for j in list(js.values())]
write = [round(j['index']['bytes_written']['value_after_commit']
        ['max_value'][0] / 1_000_000_000, 2) for j in list(js.values())]
total = [s+i for s, i in zip(read, write)]
bytes_df = {
    'version': version,
    'bytes_read': read,
    'bytes_written': write,
    'total': total
}
bytes_df = pd.DataFrame(bytes_df)
create_total_plot(bytes_df, file='bytes.png',
                title="Bytes read and write",
                v1="bytes_read", v2="bytes_written", ylabel="Size in GB")
# }}

# Max Rss plot {{
maxrss = [round(j['gc']['major_heap_top_bytes'][-1] / 1_000_000, 2) for j in list(js.values())]
maxrss_df = {
    'version': version,
    'maxrss': maxrss
}
df = pd.DataFrame(maxrss_df)
create_bar_plot(maxrss_df, 'maxrss', file='maxrss.png',
                title="Max memory usage",
                xlabel="",
                ylabel="major_heap_top_bytes in MB",
                color="LemonChiffon")
# }}

