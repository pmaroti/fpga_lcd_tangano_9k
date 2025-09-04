module dual_port_ram #(
    parameter DATA_WIDTH = 8,    // number of bits per word
    parameter ADDR_WIDTH = 10     // number of address bits (depth = 2^ADDR_WIDTH)
)(
    input  wire                   clk,      // clock (shared for both ports)


    // Port A
    input  wire                   we_a,     // write enable A
    input  wire [ADDR_WIDTH-1:0]  addr_a,   // address A
    input  wire [DATA_WIDTH-1:0]  din_a,    // data in A
    output reg  [DATA_WIDTH-1:0]  dout_a,   // data out A

    // Port B
    input  wire                   we_b,     // write enable B
    input  wire [ADDR_WIDTH-1:0]  addr_b,   // address B
    input  wire [DATA_WIDTH-1:0]  din_b,    // data in B
    output reg  [DATA_WIDTH-1:0]  dout_b    // data out B
);

    // Shared memory array
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        // Port A operations
        if (we_a) begin
            mem[addr_a] <= din_a;    // write
        end else 
            dout_a <= mem[addr_a];       // synchronous read

        // Port B operations
        if (we_b) begin
            mem[addr_b] <= din_b;    // write
        end else 
            dout_b <= mem[addr_b];       // synchronous read
    end

endmodule
