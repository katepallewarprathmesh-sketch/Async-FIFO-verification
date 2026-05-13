# Async-FIFO-verification

This repository includes a synchronous FIFO design and a complete SystemVerilog verification environment.

## Files

- `rtl/sync_fifo.sv`: Parameterized synchronous FIFO implementation.
- `tb/tb_sync_fifo.sv`: SystemVerilog verification bench with functional tests, boundary tests, error injection, assertions, and coverage sampling.
- `Makefile`: Basic simulation helper for `iverilog`.

## How to run

If `iverilog` is installed, run:

```sh
make
```

If you have another simulator, update the `SIM` variable in `Makefile` and run the simulator with `-g2012` support.

## Verification features

- reset behavior check
- basic write/read functionality
- full/empty boundary verification
- overflow/underflow injection tests
- random stress testing over many cycles
- structural assertions for overflow/underflow
- runtime consistency checks for `count`, `full`, and `empty`

