import re, json, pandas as pd, matplotlib.pyplot as plt, numpy as np
s = open('slice.txt').read() # ack -B3 "(ended|Starting)" logs.txt  | ack "(ended|Starting|Go for)" > slice.txt
ends = re.findall('GC ended. ({[^}]*})', s)
starts = re.findall('lvl(\d*): Go for gc on (\d*)', s)[:len(ends)]
j = json.loads(open('summary.json').read())
print(len(starts))
print(len(ends))
rows = []
for start, end in zip(starts, ends):
    d = json.loads(end)
    d['gc_lvl_target'] = int(start[0])
    d['gc_lvl_replay_head'] = int(start[1])
    rows.append(d)
df = pd.DataFrame(rows)
plt.close('all')
plt.plot(df.gc_lvl_target, df.duration, label='end to end (start to finalise)')
plt.plot(df.gc_lvl_target, df.finalisation_duration, label='finalisation')
plt.plot(df.gc_lvl_target, df.read_gc_output_duration, label='read_gc_output')
plt.plot(df.gc_lvl_target, df.transfer_latest_newies_duration, label='transfer_latest_newies')
plt.plot(df.gc_lvl_target, df.swap_duration, label='swap')
plt.plot(df.gc_lvl_target, df.unlink_duration, label='unlink')

plt.legend(loc='best')
plt.yscale('log')
a = [300, 200, 100, 50, 10, 1]
b = [f'{x}s' for x in a]
c = np.asarray([300, 100, 30, 10, 1, 0.3, 0.1]) / 1000
d = [f'{x * 1000:.1f}ms' for x in c]
plt.yticks(np.r_[a, c], b + d)

plt.grid(True, 'major', 'y')
plt.xlabel('block level')
plt.suptitle('GC timings on hangzhou replay - 79 GCs total - replay duration 3.5h \nreplay 4th august 2022 - irmin main 4th august 2022 - tezos master 3rd august 2022 (+replay, +gc)\nlaunching gc when previous finished, distance 10 blocks in the past instead of 6 cycles (causes small suffix files)')
plt.show()

#

