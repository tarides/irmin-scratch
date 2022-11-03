import subprocess
import uuid
import os
import json
import time
from pprint import pprint
import collections

if 'screen' not in os.environ.get('TERM'):
    print(f"\033[31mYou seem to not be within a screen session!!!\033[0m");
    time.sleep(0.5)

# Part 1 - Define an abstraction to interact with a bash session ***************
token = str(uuid.uuid4())

class Shell:
    def __init__(self):
        self.p = subprocess.Popen(
            ['/bin/bash'],
            shell=False,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            encoding='utf-8',
        )

    def write(self, cmd):
        assert '\n' not in cmd
        cmd = cmd + f';\necho {token} $?;\n'
        self.p.stdin.write(cmd)
        self.p.stdin.flush()

    def read(self):
        buf = ""
        while True:
            line = self.p.stdout.readline()
            if line.startswith(token):
                code = int(line.replace(token, "").strip('\n '))
                return code, buf
            else:
                if len(line.strip()) > 0:
                    print(line[:-1]) # Strip trailing new line
                buf += line

    def run(self, cmd):
        a = "\033[32m"
        b = "\033[0m"
        c = "\033[33m"
        s = f"** {cmd} **"
        if len(s) <= 80 and '\n' not in cmd:
            print(a + s + '*' * (80 - len(s)) + b)
        else:
            print(a + '*' * 80 + b)
            print(a + cmd + b)
        self.write(cmd)
        code, output = self.read()
        if code != 0:
            print(f"{c}> exit code={code}{b}")
        return code, output

    def test(self, cmd):
        code, output = self.run(cmd)
        return code

    def __call__(self, cmd):
        code, output = self.run(cmd)
        if code != 0:
            exit(code)
        return output

    def stop(self):
        self.p.kill()
        print()

# Part 2 - Define a function that runs one replay ******************************
def set_remote(sh, user, repo):
    code = sh.test(f"""git remote set-url {user} https://github.com/{user}/{repo}.git """)
    if code != 0:
        sh(f"""git remote add {user} https://github.com/{user}/{repo}.git """)
    sh(f"""git fetch {user} """)

def clone_cd(sh, repos_root, dirname, url):
    path = os.path.join(repos_root, dirname)
    code = sh.test(f"""cd {path} """)
    if code != 0:
        sh(f"""cd {repos_root} """)
        sh(f"""git clone {url} {dirname} """)
        sh(f"""cd {path} """)

def header(s):
    s = f'** {s} '
    s = s + '*' * (100 - len(s))
    a = "\033[32m"
    b = "\033[0m"
    print(f"\n{a}{s}{b}")

def run_one(repos_root, artefacts_root, run_name, repr_ref, index_ref, irmin_ref, tezos_ref, ram_constraint, dry_run, replay_args):
    x = replay_args.replace('\\\n', ' ').replace('\n', ' ').replace('  ', ' ').replace('  ', ' ')
    print(f"""> run one
    artefacts_root={artefacts_root}
    repos_root={repos_root}
    run_name={run_name}
    repr_ref={repr_ref}
    index_ref={index_ref}
    irmin_ref={irmin_ref}
    tezos_ref={tezos_ref}
    ram_constraint={ram_constraint}
    dry_run={dry_run}
    replay_args={x}
    """)

    artefacts = os.path.join(artefacts_root, run_name)
    logs = os.path.join(artefacts, 'logs.txt')
    tezos = os.path.join(repos_root, "tezos")
    irmin = os.path.join(repos_root, "irmin")
    index = os.path.join(repos_root, "index")
    repr = os.path.join(repos_root, "repr")

    if os.path.exists(artefacts):
        raise Exception(f"artefacts directory should not exist")

    sh = Shell()
    header("GLOBAL CONFIGS")
    sh(f"""git config --global user.email "tmp@example.com" """)
    sh(f"""git config --global user.name "Tmp" """)
    sh(f""". "$HOME/.cargo/env" """)

    header("REPR REPO")
    clone_cd(sh, repos_root, "repr", "https://github.com/mirage/repr.git")
    set_remote(sh, "samoht", "repr")
    set_remote(sh, "icristescu", "repr")
    set_remote(sh, "ngoguey42", "repr")
    sh(f"""git switch --discard-changes -d '{repr_ref}' """)
    repr_rev = sh(f"""git describe --always --dirty --broken """).strip()

    header("INDEX REPO")
    clone_cd(sh, repos_root, "index", "https://github.com/mirage/index.git")
    set_remote(sh, "samoht", "index")
    set_remote(sh, "icristescu", "index")
    set_remote(sh, "ngoguey42", "index")
    sh(f"""git switch --discard-changes -d '{index_ref}' """)
    index_rev = sh(f"""git describe --always --dirty --broken """).strip()

    header("IRMIN REPO")
    clone_cd(sh, repos_root, "irmin", "https://github.com/mirage/irmin.git")
    set_remote(sh, "samoht", "irmin")
    set_remote(sh, "icristescu", "irmin")
    set_remote(sh, "ngoguey42", "irmin")
    set_remote(sh, "metanivek", "irmin")
    set_remote(sh, "art-w", "irmin")
    sh(f"""git switch --discard-changes -d '{irmin_ref}' """)
    irmin_rev = sh(f"""git describe --always --dirty --broken """).strip()

    header("TEZOS REPO")
    clone_cd(sh, repos_root, "tezos", "https://gitlab.com/tezos/tezos.git")
    set_remote(sh, "samoht", "tezos")
    set_remote(sh, "icristescu", "tezos")
    set_remote(sh, "ngoguey42", "tezos")
    set_remote(sh, "metanivek", "tezos-mirror")
    sh(f"""git switch --discard-changes -d '{tezos_ref}' """)
    tezos_rev = sh(f"""git describe --always --dirty --broken """).strip()
    # sh(f"""rm -rf _opam """)
    code = sh.test(f"""make build-deps""")
    if code != 0:
        raise Exception("Could not update tezos packages. Maybe uncomment the rf -rf above.")

    header("BUILD BINARY")
    sh(f"""eval "$(opam env)" """)
    sh(f"""opam repo add default https://opam.ocaml.org """)
    sh(f"""opam install -y ppx_deriving_yojson printbox-text printbox bentov rusage checkseum """)
    sh(f"""opam uninstall -y irmin index repr """)
    sh.test(f"""rm {tezos}/vendors/repr """)
    sh.test(f"""rm {tezos}/vendors/index """)
    sh.test(f"""rm {tezos}/vendors/irmin """)
    sh(f"""ln -s "{repr}" "{tezos}/vendors/repr" """)
    sh(f"""ln -s "{index}" "{tezos}/vendors/index" """)
    sh(f"""ln -s "{irmin}" "{tezos}/vendors/irmin" """)
    sh(f"""eval "$(opam env)" """)
    sh(f"""dune build src/bin_context """)

    header("RUN")
    message = dict(
        name = run_name,
        repr_rev = repr_rev,
        index_rev = index_rev,
        irmin_rev = irmin_rev,
        tezos_rev = tezos_rev,
        repr_ref = repr_ref,
        index_ref = index_ref,
        irmin_ref = irmin_ref,
        tezos_ref = tezos_ref,
    )
    if ram_constraint is not None:
        message['ram_constraint'] = ram_constraint
    message = json.dumps(message)
    sh(f"""echo '{message}' | jq .""")
    sh(f"""export TEZOS_CONTEXT="v" """)
    sh(f"""sync """)
    sh(f"""echo 3 >/proc/sys/vm/drop_caches """)
    if dry_run:
        sh.test(f"""systemd-run --user --scope -p MemoryMax=8G dune exec -- ./src/bin_context/replay.exe """)
        header("dry run is a success")
    else:
        sh(f"""mkdir {artefacts} """)
        if ram_constraint is not None:
            x = f"systemd-run --user --scope -p MemoryMax={ram_constraint} "
        else:
            x = ""
        sh(f"""{x}dune exec -- ./src/bin_context/replay.exe {replay_args} --stats-trace-message '{message}' {artefacts} 2>&1 | tee {logs}""")
        header("replay is a success")
    sh.stop()

# Part 3 - Declare the wished steps ********************************************
# # Comment to disable
do_dry_run = True
do_replay = True
do_summarise = True
do_pp = True

# Part 4 - Declare the wished benchmarks ***************************************
configs = []
name_suffixes = ["_a", "_b"]

repos_root = "/root"
artefacts_root = "/root/artefacts"

gc_bench_args = """--no-summary \
--keep-stats-trace \
--startup-store-copy ~/store_forgc_330/store \
--gc-when after-level-1982464 \
--gc-target hash-CoWQHoNwMtRvhkadnNxJgyHbD1TAXCNDRn4FV3vcNXaLaduTG91n \
--stop-after-first-gc \
~/replay_trace_gc.repr"""

short_bench_no_gc_args = """--no-summary \
--keep-stats-trace \
--startup-store-copy ~/store_forgc_330/store \
--block-count 1750 \
--gc-when never \
~/replay_trace_gc.repr"""

# configs.append(dict(
#     repos_root=repos_root,
#     artefacts_root=artefacts_root,
#     run_name="no-gc",
#     repr_ref="main",
#     index_ref="main",
#     irmin_ref="ngoguey42/for-replay",
#     tezos_ref="ngoguey42/replay_oct22",
#     ram_constraint="8G",
#     replay_args=short_bench_no_gc_args,
# ))

configs.append(dict(
    repos_root=repos_root,
    artefacts_root=artefacts_root,
    run_name="with-gc",
    repr_ref="main",
    index_ref="main",
    irmin_ref="ngoguey42/for-replay",
    tezos_ref="ngoguey42/replay_oct22",
    ram_constraint="8G",
    replay_args=gc_bench_args,
))

configs.append(dict(
    repos_root=repos_root,
    artefacts_root=artefacts_root,
    run_name="pr-2085",
    repr_ref="main",
    index_ref="main",
    irmin_ref="ngoguey42/gc-read-with-replay",
    tezos_ref="ngoguey42/replay_oct22",
    ram_constraint="8G",
    replay_args=gc_bench_args,
))

# Part 5 - Do dry runs to assert configs are installable ***********************
if globals().get('do_dry_run') is True:
    for config in configs:
        for name_suffix in name_suffixes:
            artefacts = os.path.join(artefacts_root, config['run_name'] + name_suffix)
            if os.path.exists(artefacts):
                raise Exception(f"{artefacts} directory should not exist")
    setups = set(
        (config['repr_ref'], config['index_ref'], config['irmin_ref'], config['tezos_ref'])
        for config in configs
    )
    if len(setups) > 1:
        for repr, index, irmin, tezos in setups:
            config = dict(
                repos_root=repos_root,
                artefacts_root="/nowhere",
                run_name="dry-run",
                repr_ref=repr,
                index_ref=index,
                irmin_ref=irmin,
                tezos_ref=tezos,
                ram_constraint=None,
                replay_args=" unused ",
                dry_run=True,
            )
            run_one(**config)

# Part 6 - Run replays *********************************************************
if globals().get('do_replay') is True:
    for name_suffix in name_suffixes:
        for config in configs:
            config = config.copy()
            config['run_name'] = config['run_name'] + name_suffix
            config['dry_run'] = False
            run_one(**config)

# Part 7 - Compute summaries ***************************************************
if globals().get('do_summarise') is True:
    run_names = [
        config['run_name'] + name_suffix
        for name_suffix in name_suffixes
        for config in configs
    ]
    sh = Shell()
    tezos = os.path.join(repos_root, "tezos")
    sh(f"""cd {tezos}""")
    sh(f"""eval "$(opam env)" """)
    for run_name in run_names:
        d = os.path.join(artefacts_root, run_name)
        trace = os.path.join(d, 'stats_trace.*.trace')
        j = os.path.join(d, 'summary.json')
        sh(f"""dune exec -- ./src/bin_context/manage_stats.exe summarise {trace} > {j} """)
    sh.stop()

# Part 8 - Compute pretty-print ************************************************
if globals().get('do_pp') is True:
    runs = []
    for config in configs:
        for name_suffix in name_suffixes:
            run_name = config['run_name'] + name_suffix
            d = os.path.join(artefacts_root, run_name)
            j = os.path.join(d, 'summary.json')
            block_count = json.loads(open(j).read())['block_count']
            runs.append(dict(
                run_name=run_name,
                path=j,
                block_count=block_count,
            ))
    pprint(runs, width=100)
    sh = Shell()
    tezos = os.path.join(repos_root, "tezos")
    sh(f"""cd {tezos}""")
    sh(f"""eval "$(opam env)" """)
    x = ' '.join(
        f'-f {run["run_name"]},{run["path"]}'
        for run in runs
    )
    sh(f"""dune exec -- ./src/bin_context/manage_stats.exe pp-gc {x} > ~/pp-gc.txt""")
    c = collections.Counter([run['block_count'] for run in runs])
    block_count, _occurences = c.most_common()[0]
    x = ' '.join(
        f'-f {run["run_name"]},{run["path"]}'
        for run in runs
        if run['block_count'] == block_count
    )
    sh(f"""dune exec -- ./src/bin_context/manage_stats.exe pp {x} > ~/pp.txt """)
    sh.stop()

#
