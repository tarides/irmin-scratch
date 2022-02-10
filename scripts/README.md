## Scripts

### execute_irmin_bench.sh

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
