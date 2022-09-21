
import pandas as pd
import json
import itertools

rows = [json.loads(l) for l in open('data.txt').read().split('\n') if l]
df = pd.DataFrame(rows)
# print(df)

qualificators = 'avg_unlink_duration_wall avg_unlink_duration_user avg_unlink_duration_sys'.split(' ')
discriminators = 'file_bytes hostname ram_treatement fsync remove_method'.split(' ')

df = df.set_index(discriminators, verify_integrity=True).reset_index()

print(df.set_index(discriminators, verify_integrity=True).loc(axis=0)[:, :, "None", False, "Sys_remove"].reset_index().drop(columns=['ram_treatement', 'fsync', 'remove_method']))
print()

for k in discriminators:
    print(df.groupby([k]).avg_unlink_duration_wall.mean())
    print()

for k0, k1 in itertools.combinations(discriminators, 2):
    print(df.groupby([k0, k1]).avg_unlink_duration_wall.mean())
    print()

# for k0, k1, k2 in itertools.combinations(discriminators, 3):
#     print(df.groupby([k0, k1, k2]).avg_unlink_duration_wall.sum())
#     print()

 #
