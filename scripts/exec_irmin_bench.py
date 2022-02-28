import os
import argparse as arg
import logging as log

monthes = [
    "01",
    "02",
    "03",
    "04",
    "05",
    "06",
    "07",
    "08",
    "09",
    "10",
    "11",
    "12"
]

years = ["21", "22"]

irmin_versions = ["3.0"]

number_to_mont = {
    "01": "jan",
    "02": "feb",
    "03": "mar",
    "04": "april",
    "05": "may",
    "06": "jun",
    "07": "july",
    "08": "aug",
    "09": "sep",
    "10": "oct",
    "11": "nov",
    "12": "dec",
}


def display_header():
    print("""
+--------------------------------------------+
| Name: Bench runner                         |
+--------------------------------------------+
| Author: Étienne Marais <etienne@maiste.fr> |
| Version: 20220301                          |
+--------------------------------------------+
        """)


def convert_to_branch(month, year):
    return "bench-{}-{}".format(number_to_mont[month], year)


def verify_type(args):
    if args.month is not None and args.year is not None:
        if args.irmin is not None:
            log.error("Cant have month-year with irmin version")
            exit(1)
        else:
            return 0
    if args.irmin is not None:
        if args.month is not None or args.year is not None:
            log.error("Can't have month-year with irmin version")
            exit(1)
        else:
            return 1


def clear_locked():
    for file in os.listdir():
        if file.endswith("locked"):
            log.debug("Remove {}".format(file))
            os.remove(file)


def setup_fake_git():
    log.info("Setting up a fake git address")
    os.system("git config --global user.email \"tmp@example.com\"")
    os.system("git config --global user.name \"Tmp\"")


def checkout(branch):
    log.info("Checkout on {}".format(branch))
    cmd = "git checkout {}".format(branch)
    if os.system(cmd) != 0:
        log.error("Cant checkout on branch")
        exit(1)


def patch_strategy(required=False):
    if required:
        log.info("+Install patch")
        os.system("git cherry-pick 7e095f507cf680d1d9079a824e8a33978538f7ec")
    else:
        log.info("No patch added")


def download_trace(name="data_1343496commits.repr", dest="/tmp/data5.repr"):
    if os.path.exists(dest):
        log.info("The trace is already available on your system")
        return
    else:
        log.info("Download trace for {}".format(name))
        cmd = "wget http://data.tarides.com/irmin/{}".format(name)
        if os.system(cmd) != 0:
            log.error("Trace can't be download")
            exit(1)
        os.rename(name, dest)


def download_lock(version):
    lockfile = "irmin-{}.opam.locked".format(version)
    if os.path.exists(lockfile):
        log.info("The lock file is already available on the system")
        return
    log.info("Downloading lock file {}".format(lockfile))
    endpoint = "tarides/tezos-storage-bench/main/lockfiles/"
    address = "https://raw.githubusercontent.com/"
    cmd = "wget " + address + endpoint + lockfile
    if os.system(cmd) != 0:
        log.error("Lock file can't be download")
        exit(1)


def build_context():
    log.info("Pull data from monorepo")
    cmd = "opam monorepo pull"
    if os.system(cmd) != 0:
        log.error("Can't pull monorepo data")
        exit(1)
    log.info("Build bench repository")
    opam = "opam exec -- "
    build = "dune build --release -- ./bench"
    cmd = opam + build
    if os.system(cmd) != 0:
        log.error("Can't build ./bench in irmin")
        exit(1)


def run_bench(setup_name, tree_flags, artefacts_prefix,
              test_suff, is_user=False, systemd=None):
    opam = "opam exec -- "
    dune = "dune exec --release "
    path = "./bench/irmin-pack/tree.exe -- "
    flags = "--mode trace --no-summary "
    if not is_user:
        log.warning("Clear the cache as root")
        cmd = "sync ; echo 3 > /proc/sys/vm/drop_caches"
        log.debug("Execute {}".format(cmd))
        if os.system(cmd) != 0:
            log.error("Can't clear caches")
            exit(1)
    else:
        log.warning("Clear the cache")
        artefacts = "--artefacts {}/nope".format(artefacts_prefix)
        blobs = "--empty-blobs "
        cmd = opam + dune + path + flags + " --path-conversion=v0+v1 " + blobs + tree_flags + artefacts
        log.debug("Execute {}".format(cmd))
        if os.system(cmd):
            log.error("Can't clear cache with dry run")
            exit(1)
    log.info("Run the benchmark")
    artefact_path = os.path.join(artefacts_prefix, setup_name, test_suff)
    artefacts = "--artefacts {} ".format(artefact_path)
    stats = "--keep-stat-trace "
    cmd = ""
    if systemd is not None:
        cmd += "systemd-run --user --scope -p MemoryMax={} ".format(systemd)
    cmd += opam + dune + path + flags + stats + tree_flags + artefacts
    log.debug("Execute {}".format(cmd))
    if os.system(cmd) != 0:
        log.error("Can't run bench for {}".format(setup_name))
        exit(1)


parser = arg.ArgumentParser()
parser.add_argument("-m", "--month", type=str, choices=monthes,
                    help="Choose the month to use")
parser.add_argument("-y", "--year", type=str, choices=years,
                    help="Choose a year to use")
parser.add_argument("--patch_strategy", action="store_true",
                    help="Patch with the strategy changed")
parser.add_argument("-i", "--irmin", type=str, choices=irmin_versions,
                    help="Select the version, incompatible with -m and -y")
parser.add_argument("-u", "--user", action="store_true",
                    help="Run as a user")
parser.add_argument("-d", "--debug", action="store_true",
                    help="Set debug mode")
parser.add_argument("--rm", action="store_true",
                    help="Clear lockfile")
parser.add_argument("--git", action="store_true",
                    help="Set a fake git profile for commit")
parser.add_argument("-p", "--path", type=str, help="Path to the trace")
parser.add_argument("-s", "--systemd", type=str,
                    help="Set the memory consumption limit.")

if __name__ == "__main__":
    display_header()
    args = parser.parse_args()

    if args.debug:
        log.basicConfig(level=log.DEBUG,
                        format='%(asctime)s - %(levelname)s: %(message)s')
    else:
        log.basicConfig(level=log.INFO,
                        format='%(asctime)s - %(levelname)s: %(message)s')

    tag = verify_type(args)
    branch = ""
    lockfile = ""
    if tag == 0:
        lockfile = "{}-{}".format(args.year, args.month)
        branch = convert_to_branch(args.month, args.year)
    elif tag == 1:
        lockfile = "{}".format(args.irmin)
        branch = "bench-{}".format(args.irmin)
    else:
        log.error("Unknown tag, exit")
        exit(1)

    if args.rm:
        clear_locked()

    if args.git:
        setup_fake_git()

    checkout(branch)
    patch_strategy(args.patch_strategy)

    tree_path = args.path if args.path is not None else "/tmp/data5.repr"
    download_lock(lockfile)
    download_trace(dest=tree_path)

    artefacts_prefix = os.path.join(os.getcwd(), branch)
    setup_name = "benchmarks"
    build_context()

    log.info("Run benchmark with 200_000 commits")
    tree_flags = tree_path + " --ncommits-trace 200000 "
    test_suffix = "packet_a"
    run_bench(setup_name, tree_flags, artefacts_prefix, test_suffix,
              is_user=args.user, systemd=args.systemd)
    test_suffix = "packet_b"
    run_bench(setup_name, tree_flags, artefacts_prefix, test_suffix,
              is_user=args.user, systemd=args.systemd)

    log.info("Run benchmarks with 1_343_496")
    tree_flags = tree_path + " --ncommits-trace 1343496 "
    test_suffix = "packet_a_all"
    run_bench(setup_name, tree_flags, artefacts_prefix, test_suffix,
              is_user=args.user, systemd=args.systemd)
    test_suffix = "packet_b_all"
    run_bench(setup_name, tree_flags, artefacts_prefix, test_suffix,
              is_user=args.user, systemd=args.systemd)
