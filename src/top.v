module top(
    input wire clk,
    input wire btn1,
    output wire [5:0] led,
    output wire ioSclk,
    output wire ioSdin,
    output wire ioCs,
    output wire ioDc,
    output wire ioReset
);

  reg pixel = 1;
  reg [6:0] x = 0;
  reg [5:0] y = 0;
  reg pixel_we = 0;
  wire [1:0] pixel_state;

  assign led = ~x[5:0];

  reg [32:0] btnBounceCounter = 0;
  localparam BTN_IDLE = 2'b00;
  localparam BTN_STATE_BTN_BOUNCE = 2'b01;

  reg state_btn = BTN_IDLE;

  sd1306 #(.STARTUP_WAIT(32'd10000000)) display (
      .clk(clk),
      .ioSclk(ioSclk),
      .ioSdin(ioSdin),
      .ioCs(ioCs),
      .ioDc(ioDc),
      .ioReset(ioReset),
      
      .pixel(pixel),
      .x(x),
      .y(y),
      .pixel_we(pixel_we),
      .pixel_state(pixel_state)

  );


    always @(posedge clk) begin
        case (state_btn)
            BTN_IDLE: begin
                pixel_we <= 0;
                if (pixel_state == 2'b00) begin
                    if (btn1 == 0) begin
                        state_btn <= BTN_STATE_BTN_BOUNCE;
                        btnBounceCounter <= 0;
                    end
                end
            end 
            BTN_STATE_BTN_BOUNCE: begin
                if (btnBounceCounter < 1_000_000) begin
                    btnBounceCounter <= btnBounceCounter + 1;
                end else
                    if (btn1 == 1) begin
                            x <= x + 1;
                            y <= y + 1;
                            pixel_we <= 1;
                            state_btn <= BTN_IDLE;
                    end
            end
        endcase
    end
endmodule