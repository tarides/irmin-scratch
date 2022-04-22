# +--------------------------------------------+
# | Name: Lib_context graph generator          |
# | Author: Etienne Marais <etienne@maiste.fr> |
# | Version: 20220329                          |
# +--------------------------------------------+

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

# CPU TIME PLO {{
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

# Merging time plot {{
nb_merge = [j['index']['nb_merge']['value_after_commit']
            ['max_value'][0] for j in list(js.values())]
merge_df = {
    'version': version,
    'nb_merge': nb_merge}
merge_df = pd.DataFrame(merge_df)
create_bar_plot(merge_df, 'nb_merge', file='max_merge_after_commit.png',
                title="Number of (index) merges",
                xlabel="", ylabel="Number of merge per block",
                color="antiquewhite")
# }}

# Index and pack store cumulative plot {{
store_pack = [round(j['disk']['store_pack']['value_after_commit']
              ['max_value'][0] / 1_000_000_000, 2) for j in list(js.values())]
index_data = [round(j['disk']['index_data']['value_after_commit']
              ['max_value'][0] / 1_000_000_000, 2) for j in list(js.values())]
total = [s+i for s, i in zip(store_pack, index_data)]
store_df = {
    'version': version,
    'index':  index_data,
    'pack file': store_pack,
    'total': total
}
store_df = pd.DataFrame(store_df)
create_total_plot(store_df, file="store_index.png",
                  title="Size of index and pack store",
                  v1="index", v2="pack file",  ylabel="Size in GB")
# }}

# Transaction per second plot {{
tz = [round(j['block_specs']['tzop_count_tx']['value']['diff'] /
            j['elapsed_wall'], 2) for j in list(js.values())]
tz_df = {
    'version': version,
    'tzx': tz
}
tz_df = pd.DataFrame(tz_df)
create_bar_plot(tz_df, 'tzx', file='tztx_per_second.png',
                title="Transaction(s) per second",
                xlabel="",
                ylabel="Average number of transactions per seconds",
                color="plum")
# }}

# Operations per second plot {{
tz = [round(j['block_specs']['tzop_count']['value']['diff'] /
            j['elapsed_wall'], 2) for j in list(js.values())]
tz_df = {
    'version': version,
    'tz': tz
}
tz_df = pd.DataFrame(tz_df)
create_bar_plot(tz_df, 'tz', file='tzops_per_second.png',
                title="Operation(s) per second",
                xlabel="",
                ylabel="Average number of operations per seconds",
                color="LightPink")
# }}

# Store evolution over time {{
block_levels = []
store = dict()
store2 = dict()
for k in js.keys():
    tmp = js[k]['disk']['store_pack']['value_after_commit']['evolution']
    store[k] = [(x - y) / 1_000_000 for x, y in zip(tmp[1:], tmp[:-1])]
    store2[k] = [x / 1_000_000_000 for x in tmp[1:]]
    block_levels = js[k]['block_specs']['level_over_blocks'][1:]
create_multiline_plot(block_levels, store, file="store_evolution.png",
                      title="Pack store evolution over time",
                      xlabel="Blocks",
                      ylabel="Number of MB added")
create_multiline_plot(block_levels, store2, file="store_evolution_2.png",
                      title="Pack store evolution over time",
                      xlabel="Blocks",
                      ylabel="Pack store size in GB")
# }}

# Transaction evolution {{
block_levels = []
tz = dict()
for k in js.keys():
    tz[k] = [x / y for x, y in zip(js[k]['block_specs']['tzop_count_tx']['diff_per_block']
                                   ['evolution'][1:], js[k]['span']['block']['duration']['evolution'][1:])]
    block_levels = js[k]['block_specs']['level_over_blocks'][1:]
create_multiline_plot(block_levels, tz, file="tz_evolution.png",
                      title="TPS evolution over blocks in Hangzou",
                      xlabel="Blocks",
                      ylabel="TPS per block")
# }}

# Number of transactions per block over time {{
data = dict()
data['tz'] = js[version[0]
                ]['block_specs']['tzop_count_tx']['diff_per_block']['evolution'][1:]
create_multiline_plot(block_levels, data, file="tz_count.png",
                      title="Number of transactions per block in Hangzou",
                      xlabel="Blocks",
                      ylabel="Number of transactions")
# }}


# Commit time plot {{
commit = [round(j['span']['commit']['duration']['max_value'][0], 2)
          for j in list(js.values())]
commit_df = {
    'version': version,
    'commit': commit
}
commit_df = pd.DataFrame(commit_df)
create_bar_plot(commit_df, 'commit', file='commit_tail_latency.png',
                title='Maximal commit time', xlabel='',
                ylabel='Time in seconds', color="Lavender")
# }}

# Max Rss plot {{
maxrss = [round(j['rusage']['maxrss']['value_after_commit']
                ['max_value'][0] / 1_000_000, 2) for j in list(js.values())]
maxrss_df = {
    'version': version,
    'maxrss': maxrss
}
df = pd.DataFrame(maxrss_df)
create_bar_plot(maxrss_df, 'maxrss', file='maxrss.png',
                title="Maximal RAM memory usage (Maxrss)",
                xlabel="",
                ylabel="RAM Usage in GB",
                color="LemonChiffon")
# }}

# Gc Major Heap plot {{
gc_df = [round(j['gc']['major_heap_bytes']['value_after_commit']
               ['max_value'][0] / 1_000_000, 2) for j in list(js.values())]
gc_df = {
    'version': version,
    'gc': maxrss
}
gc_df = pd.DataFrame(gc_df)
create_bar_plot(gc_df, 'gc', file='gc_major_heap.png',
                title="Maximal Major Heap size",
                xlabel="",
                ylabel="Major heap in MB",
                color="LemonChiffon")
#  }}
