
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

pd.set_option('display.max_rows', 200)

rows = []
for fname in os.listdir('csv'):
    entry_count = int(fname.replace('_', ''))
    header, *ll = open('csv/' + fname).readlines()
    for l in ll:
        a, b, c, d = l.replace('\n', '').split(',')
        rows.append(dict(
            entry_count = entry_count,
            is_branch = bool(int(a)),
            depth = int(b),
            pred_count = int(c),
            count = int(d),
        ))
df = pd.DataFrame(rows)
df['totpred'] = df['count'] * df.pred_count
print(df)


# Sanity check on file integrity
d = df.copy()
d['tot'] = d.pred_count * d['count']
d = d[d.is_branch == False].groupby('entry_count')['tot'].sum()
for k, v in d.items():
    assert k == v, (k, v)




plt.close('all')

d = df.groupby(['entry_count', 'is_branch'])[['totpred', 'count']].sum().reset_index()
d['filling'] = d.totpred / d['count']
plt.plot(d[d.is_branch].entry_count, d[d.is_branch].filling,
         label='inodes of kind Tree',
         c='cornflowerblue'
         )
plt.plot(d[~d.is_branch].entry_count, d[~d.is_branch].filling,
         label='inodes of kind Values',
         c='orange'
         )


db = d[~d.is_branch]
diffs = np.c_[
    db.filling.diff(),
    db.filling[::-1].diff()[::-1]
]
db['lows'] = (diffs < 0).all(axis=1)
db['highs'] = (diffs > 0).all(axis=1)

dl = d[d.is_branch]
diffs = np.c_[
    dl.filling.diff(),
    dl.filling[::-1].diff()[::-1]
]
dl['lows'] = (diffs < 0).all(axis=1)
dl['highs'] = (diffs > 0).all(axis=1)


for _, row in db.iterrows():
    if row.lows:
        plt.plot([row.entry_count], [row.filling], 'o', c='orange')
        plt.text(row.entry_count, row.filling,
                 f"suboptimal around\n{row.entry_count:,d} entries", fontsize=7,
                 horizontalalignment='left', verticalalignment='top',
                 )
    if row.highs:
        plt.plot([row.entry_count], [row.filling], 'o', c='orange')
        plt.text(row.entry_count, row.filling,
                 f"optimal around\n{row.entry_count:,d} entries", fontsize=7,
                 horizontalalignment='left', verticalalignment='top',
                 )

for _, row in dl.iterrows():
    if row.lows:
        plt.plot([row.entry_count], [row.filling], 'o', c='cornflowerblue')
        plt.text(row.entry_count, row.filling,
                 f"suboptimal around\n{row.entry_count:,d} entries", fontsize=7,
                 horizontalalignment='left', verticalalignment='bottom',
                 )


plt.xscale('log')

xs = np.round(32 ** np.arange(5.5, -0.01, -1/2)[::-1])
plt.xticks(xs, [
    f'{int(x):,d}'
    for x in xs
], rotation=22, ha='right', rotation_mode='anchor')
plt.xlim(1, d.entry_count.max())

plt.yticks([
    0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32
    # 0, 4, 8, 12, 16, 20, 24, 28, 32
])
plt.ylim(-0.5, 32.5)

plt.grid(True)

plt.legend(loc='upper right', bbox_to_anchor=(1., -0.25), ncol=2)

# plt.legend(loc=1, mode='expand', numpoints=1, ncol=4, fancybox = True, fontsize='small')
# plt.legend(loc='below')
plt.suptitle('Log plot of the cyclical behaviour or inode trees')
plt.xlabel('number of entries in the node')
plt.ylabel('average number of inode predecessors')
plt.tight_layout()
# plt.legend(loc=(1.04,0))
# plt.legend(loc="lower center", bbox_to_anchor=(0.5, -0.3))
# plt.legend(loc="lower center", bbox_to_anchor=(0.5, -0.3))



plt.show()
# plt.savefig('inode_tree_algo.png')


#
