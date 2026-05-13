module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
    input logic clk,
    input logic rst_n,
    input logic wr_en,
    input logic rd_en,
    input logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout,
    output logic full,
    output logic empty,
    output logic [ADDR_WIDTH:0] count
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH:0] used;

    assign full = (used == DEPTH);
    assign empty = (used == 0);
    assign count = used;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            used <= '0;
            dout <= '0;
        end else begin
            logic write_valid;
            logic read_valid;

            write_valid = wr_en && !full;
            read_valid = rd_en && !empty;

            if (write_valid) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1;
            end

            if (read_valid) begin
                dout <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end

            if (write_valid && !read_valid) used <= used + 1;
            else if (!write_valid && read_valid) used <= used - 1;
        end
    end

endmodule
