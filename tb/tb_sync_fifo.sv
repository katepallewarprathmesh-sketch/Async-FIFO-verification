`timescale 1ns/1ps

interface fifo_if #(parameter int DATA_WIDTH = 8, parameter int DEPTH = 16)
  (input logic clk, input logic rst_n);

  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] din;
  logic [DATA_WIDTH-1:0] dout;
  logic full;
  logic empty;
  logic [$clog2(DEPTH):0] count;

  modport dut (input clk, rst_n, wr_en, rd_en, din, output dout, full, empty, count);
  modport tb (output wr_en, rd_en, din, input dout, full, empty, count);

endinterface

module tb_sync_fifo;
  localparam int DATA_WIDTH = 8;
  localparam int DEPTH = 16;

  logic clk;
  logic rst_n;
  fifo_if #(DATA_WIDTH, DEPTH) vif(.clk(clk), .rst_n(rst_n));

  sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
      .clk(clk),
      .rst_n(rst_n),
      .wr_en(vif.wr_en),
      .rd_en(vif.rd_en),
      .din(vif.din),
      .dout(vif.dout),
      .full(vif.full),
      .empty(vif.empty),
      .count(vif.count)
  );

  integer errors;
  logic [DATA_WIDTH-1:0] expected_data_queue[$];

  covergroup fifo_cover @(posedge clk);
    coverpoint vif.full;
    coverpoint vif.empty;
    coverpoint vif.count;
    cross vif.wr_en, vif.rd_en;
    cross vif.full, vif.empty;
  endgroup
  fifo_cover coverage = new();

  initial begin
    clk = 0;
    rst_n = 1;
    vif.wr_en = 0;
    vif.rd_en = 0;
    vif.din = '0;
    errors = 0;

    reset_fifo();
    basic_functionality_test();
    full_empty_boundary_test();
    illegal_operation_test();
    random_stress_test(400);

    if (errors == 0) begin
      $display("\n=== TEST PASSED: all FIFO checks completed successfully ===");
    end else begin
      $display("\n=== TEST FAILED: %0d verification errors detected ===", errors);
    end

    $display("Coverage points were sampled during simulation. Examine the simulator coverage report for detailed counts.");
    $finish;
  end

  always #5 clk = ~clk;

  task reset_fifo();
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    vif.wr_en = 0;
    vif.rd_en = 0;
    vif.din = '0;
    repeat (2) @(posedge clk);
    expected_data_queue.delete();
    if (vif.count != 0) begin
      $error("FIFO did not reset to empty state");
      errors++;
    end
  endtask

  task automatic sample_and_check(bit wr, bit rd, logic [DATA_WIDTH-1:0] data);
    bit full_before;
    bit empty_before;
    full_before = vif.full;
    empty_before = vif.empty;

    vif.wr_en = wr;
    vif.rd_en = rd;
    vif.din = data;

    @(posedge clk);
    coverage.sample();

    if (wr && !full_before) begin
      expected_data_queue.push_back(data);
    end

    if (rd && !empty_before) begin
      if (expected_data_queue.size() == 0) begin
        $error("Read occurred while no data was expected");
        errors++;
      end else begin
        logic [DATA_WIDTH-1:0] expected = expected_data_queue.pop_front();
        if (expected !== vif.dout) begin
          $error("Data mismatch: expected 0x%0h, got 0x%0h at time %0t", expected, vif.dout, $time);
          errors++;
        end
      end
    end

    check_invariants();
  endtask

  task automatic check_invariants();
    if (vif.count != expected_data_queue.size()) begin
      $error("Count mismatch: count=%0d expected=%0d at time %0t", vif.count, expected_data_queue.size(), $time);
      errors++;
    end
    if (vif.full !== (vif.count == DEPTH)) begin
      $error("Full flag mismatch at time %0t: full=%0b count=%0d", $time, vif.full, vif.count);
      errors++;
    end
    if (vif.empty !== (vif.count == 0)) begin
      $error("Empty flag mismatch at time %0t: empty=%0b count=%0d", $time, vif.empty, vif.count);
      errors++;
    end
    if (vif.count > DEPTH) begin
      $error("Count out of bounds: count=%0d at time %0t", vif.count, $time);
      errors++;
    end
  endtask

  task automatic basic_functionality_test();
    $display("[TEST] Running basic functionality test...");
    sample_and_check(1, 0, 8'hA5);
    sample_and_check(1, 0, 8'h5A);
    sample_and_check(0, 1, 8'h00);
    sample_and_check(0, 1, 8'h00);
    if (errors == 0) $display("[TEST] Basic functionality test passed");
  endtask

  task automatic full_empty_boundary_test();
    $display("[TEST] Running full/empty boundary test...");
    while (!vif.full) begin
      sample_and_check(1, 0, $urandom);
    end
    if (!vif.full) begin
      $error("FIFO failed to reach full state");
      errors++;
    end

    while (!vif.empty) begin
      sample_and_check(0, 1, '0);
    end
    if (!vif.empty) begin
      $error("FIFO failed to drain to empty state");
      errors++;
    end
    $display("[TEST] Full/empty boundary test completed");
  endtask

  task automatic illegal_operation_test();
    $display("[TEST] Running overflow/underflow injection test...");
    // Fill FIFO to capacity
    while (!vif.full) begin
      sample_and_check(1, 0, $urandom);
    end
    logic [DATA_WIDTH-1:0] forced = 8'hFF;
    int count_before = vif.count;
    sample_and_check(1, 0, forced);
    if (vif.count != count_before) begin
      $error("Illegal write changed count when FIFO was full");
      errors++;
    end

    // Drain FIFO completely
    while (!vif.empty) begin
      sample_and_check(0, 1, '0);
    end
    count_before = vif.count;
    sample_and_check(0, 1, '0);
    if (vif.count != count_before) begin
      $error("Illegal read changed count when FIFO was empty");
      errors++;
    end
    $display("[TEST] Overflow/underflow injection test completed");
  endtask

  task automatic random_stress_test(int cycles);
    $display("[TEST] Running random stress test for %0d cycles...", cycles);
    for (int i = 0; i < cycles; i++) begin
      bit wr = $urandom_range(0, 1);
      bit rd = $urandom_range(0, 1);
      logic [DATA_WIDTH-1:0] data = $urandom;

      if (vif.full) wr = 0;
      if (vif.empty) rd = 0;
      sample_and_check(wr, rd, data);
    end
    $display("[TEST] Random stress test completed");
  endtask

  // Assertions for structural and behavioral correctness
  property no_overflow;
    @(posedge clk) disable iff (!rst_n) !(vif.wr_en && vif.full);
  endproperty
  assert property (no_overflow)
    else $error("[ASSERT] Overflow attempted when FIFO was full at time %0t", $time);

  property no_underflow;
    @(posedge clk) disable iff (!rst_n) !(vif.rd_en && vif.empty);
  endproperty
  assert property (no_underflow)
    else $error("[ASSERT] Underflow attempted when FIFO was empty at time %0t", $time);

endmodule
