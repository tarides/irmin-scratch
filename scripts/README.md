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
