## Scripts


### exec_irmin_bench.py

* __Purpose__: this script runs benchmarks on 200k commits and full commits trace.
* __Requiered__: you need to have an `opam switch` with `ocaml.4.13.1`, `opam-monorepo.0.2.7` and `dune.2.9.3`
* __Usage__:
  ```sh
  python3 ./exec_irmin_bench.py ([-m month]  [-y year] | [-i irmin_version]) [--rm] [-d]
  ```
* __Example__:
   ```sh
   ./execute_irmin_bench/sh -m 02 -y 22 -d --rm
   ```

### execute_irmin_bench.sh (DEPRACTED)

* __Purpose__: this script runs benchmarks on 200k commits and full commits trace.
* __Requiered__: you have to download the commit fil on the tarides website. The branches must be set on `index`, `repr` and `irmin`with the format `bench-month-year`.
* __Usage__:
  ```sh
  ./execute_irmin_bench.sh [month-year] [printbox.0.5 | printbox.0.6 | nope] [patch-minimal | nope]
  ```
* __Example__:
   ```sh
   ./execute_irmin_bench/sh feb-22 printbox.0.6 patch-minimal
   ```

### install_tezos.sh

* __Purpose__: this script installs `Tezos` on the current machine.
* __Required__: nothing
* __Usage__:
  ```sh
  ./install_tezos.sh
  ```
* __Example__:
  ```sh
  ./install_tezos.sh
  ```

## exec_tezos_replay.sh

* __Purpose__: this script runs a `replay` on a specific trace.
* __Required__: the trace and the store to be installed.
* __Usage__:
  ```sh
  ./exec_tezos_replay [name] [tezos-branch] [repr-branch] [index-branch] [irmin-branch] \
                      [path/to/trace] <sizeG> <indexing_strategy> <progress_version>
  ```
* __Example__:
  ```sh
  ./exec_tezos_replay irmin3.0-minimal add-trace-replay \
                      main main main trace/replay.repr \
                      8G "nope" "nope"
  ```

### produce_graph.py

* __Purpose__: this script extracts graphs from `lib_context` replay summaries.
* __Requiered__: `seaborn`, `json`, `numpy`, `pandas` and, `matplotlib`
* __Usage__:
  ```sh
  python3 ./produce_graphs.py [-p /path/to/summary/<name>-<version>[-<indexing_strategy>].json]
  ```
* __Example__:
   ```sh
   python3 ./produce_graphs.py -p /tmp/irmin-2.10.json -p /tmp/irmin-3.0-minmal.json
   ```
