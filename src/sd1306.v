`default_nettype none

module sd1306
#(
  parameter STARTUP_WAIT = 32'd10000000
)
(
    input wire clk,
    output wire ioSclk,
    output wire ioSdin,
    output wire ioCs,
    output wire ioDc,
    output wire ioReset,

    input wire pixel,
    input wire [6:0] x,
    input wire [5:0] y,
    input wire pixel_we,
    output reg [1:0] pixel_state
);

  localparam STATE_INIT_POWER = 3'b000;
  localparam STATE_LOAD_INIT_CMD = 3'b001;
  localparam STATE_SEND = 3'b010;
  localparam STATE_CHECK_FINISHED_INIT = 3'b011;
  localparam STATE_LOAD_DATA = 3'b100;

  reg [32:0] counter = 0;
  reg [2:0]  state = 0;

  localparam STATE_PIXEL_IDLE   = 2'b00;
  localparam STATE_PIXEL_READ   = 2'b01;
  localparam STATE_PIXEL_WRITE  = 2'b10;

  reg dc = 1;
  reg sclk = 1;
  reg sdin = 0;
  reg reset = 1;
  reg cs = 0;

  reg [7:0] dataToSend = 0; // current byte being sent to the display
  reg [3:0] bitNumber = 0; // counts down from 7 to 0

  reg porta_we = 0;   // display always reads through port A
  reg [9:0] porta_addr = 0;
  reg [7:0] porta_din;
  wire [7:0] porta_dout;

  reg portb_we = 0;
  reg [9:0] portb_addr;
  reg [7:0] portb_din;
  wire [7:0] portb_dout;

  reg [7:0] pixelmemvalue;

dual_port_ram #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(10)
) screenBufferRAM (
    .clk(clk),
    // Port A
    .we_a(porta_we),
    .addr_a(porta_addr),  // address A
    .din_a(portb_din),    // data in A
    .dout_a(porta_dout),   // data out A  

    // Port B
    .we_b(portb_we),
    .addr_b(portb_addr),  // address B
    .din_b(portb_din),    // data in B
    .dout_b(portb_dout)    // data out B
);



  localparam SETUP_INSTRUCTIONS = 23;
  reg [(SETUP_INSTRUCTIONS*8)-1:0] startupCommands = {
    8'hAE,  // display off

    8'h81,  // contast value to 0x7F according to datasheet
    8'h7F,  

    8'hA6,  // normal screen mode (not inverted)

    8'h20,  // horizontal addressing mode
    8'h00,  

    8'hC8,  // normal scan direction

    8'h40,  // first line to start scanning from

    8'hA1,  // address 0 is segment 0

    8'hA8,  // mux ratio
    8'h3f,  // 63 (64 -1)

    8'hD3,  // display offset
    8'h00,  // no offset

    8'hD5,  // clock divide ratio
    8'h80,  // set to default ratio/osc frequency

    8'hD9,  // set precharge
    8'h22,  // switch precharge to 0x22 default

    8'hDB,  // vcom deselect level
    8'h20,  //  0x20 

    8'h8D,  // charge pump config
    8'h14,  // enable charge pump

    8'hA4,  // resume RAM content

    8'hAF   // display on
  };
  reg [7:0] commandIndex = SETUP_INSTRUCTIONS * 8;

  assign ioSclk = sclk;
  assign ioSdin = sdin;
  assign ioDc = dc;
  assign ioReset = reset;
  assign ioCs = cs;

  always @(posedge clk) begin
    case (state)
      STATE_INIT_POWER: begin
        counter <= counter + 1;
        if (counter < STARTUP_WAIT*2)
          reset <= 1;
        else if (counter < STARTUP_WAIT * 3)
          reset <= 0;
        else if (counter < STARTUP_WAIT * 4)
          reset <= 1;
        else begin
          state <= STATE_LOAD_INIT_CMD;
          counter <= 32'b0;
        end
      end
      STATE_LOAD_INIT_CMD: begin
        dc <= 0;
        dataToSend <= startupCommands[(commandIndex-1)-:8'd8];
        state <= STATE_SEND;
        bitNumber <= 3'd7;
        cs <= 0;
        commandIndex <= commandIndex - 8'd8;
      end
      STATE_SEND: begin
        if (counter == 32'd0) begin
          sclk <= 0;
          sdin <= dataToSend[bitNumber];
          counter <= 32'd1;
        end
        else begin
          counter <= 32'd0;
          sclk <= 1;
          if (bitNumber == 0)
            state <= STATE_CHECK_FINISHED_INIT;
          else
            bitNumber <= bitNumber - 1;
        end

      end
      STATE_CHECK_FINISHED_INIT: begin
          cs <= 1;
          if (commandIndex == 0) begin
            state <= STATE_LOAD_DATA;
          end
          else
            state <= STATE_LOAD_INIT_CMD; 
            porta_we <= 0;
      end
      STATE_LOAD_DATA: begin
          porta_addr <= porta_addr + 1;
          cs <= 0;
          dc <= 1;
          bitNumber <= 3'd7;
          state <= STATE_SEND;
          /*
          if (porta_addr < 400 )
            dataToSend <= 8'b1010_1010;
          else
            dataToSend <= 8'b1111_0000;
          */
          dataToSend <= porta_dout;
      end
    endcase
  end
/* Test implelmentation for button and writing to RAM
  always @(posedge clk) begin
    case (btnState)

      2'b00: begin
        if (btn1 == 0) begin
          btnState <= 2'b01;
          btnBounceCounter <= 0;
          cntr <= cntr + 1;
        end
      end

      2'b01: begin
        if (btnBounceCounter == 32'd1_000_0000) begin
          if (btn1 == 1) begin
            btnState <= 2'b10;
            portb_we <= 1;
            portb_addr <= 0;
            portb_din <= cntr;
          end
        end else begin
          btnBounceCounter <= btnBounceCounter + 1;
        end
      end

      2'b10: begin
        portb_addr <= portb_addr + 1;
        if (portb_addr == 1023) begin
          portb_we <= 0;
          btnState <= 2'b00;
        end
      end
    endcase
  end
  */

  always @(negedge clk) begin
    if (state == STATE_PIXEL_READ)
        pixelmemvalue <= portb_dout;
  end

  always @(posedge clk) begin
    case (pixel_state)
      STATE_PIXEL_IDLE: begin
        portb_we <= 0;
        if (pixel_we) begin
          pixel_state <= STATE_PIXEL_READ;
          portb_addr <= x + ( (y >> 3) << 7);
        end
      end

      STATE_PIXEL_READ: begin
        pixel_state <= STATE_PIXEL_WRITE;
      end

      STATE_PIXEL_WRITE: begin
        pixel_state <= STATE_PIXEL_IDLE;
        portb_we <= 1;
        if (pixel)
          portb_din <= pixelmemvalue |  (8'b0000_0001 << (y & 8'b0000_0111 ) );
          // portb_din <= (8'b0000_0001 << (y & 8'b0000_0111 ) );
        else
          portb_din <= pixelmemvalue & ~(8'b0000_0001 << (y & 8'b0000_0111 ) );
      end
    endcase
  end


endmodule
