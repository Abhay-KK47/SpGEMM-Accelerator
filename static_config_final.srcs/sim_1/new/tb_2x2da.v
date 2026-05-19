module tb_da;

task send_input;
input [15:0] data;
input [7:0]  dn_cfg;
begin
    // wait until accelerator is empty and input port is ready
    while (!(RDY_isEmpty && isEmpty && input_rdy))
        @(posedge CLK);

    input_data = data;
    dn_config_data = dn_cfg;
    input_en = 1;
    dn_config_en = 1;

    @(posedge CLK);

    input_en = 0;
    dn_config_en = 0;
end
endtask

    // Parameters
    parameter [3:0] STATE_IDLE = 4'b0000;
    parameter [3:0] STATE_FILL_STATIONARY = 4'b0001;
    parameter [3:0] STATE_MULT_STREAMING = 4'b0010;
    parameter CLK_PERIOD = 10;

    // Signals for maeriAccelerator
    reg CLK;
    reg RST_N;

    wire isEmpty;
    wire RDY_isEmpty;

    // DN Config
    reg [7:0] dn_config_data;
    reg dn_config_en;
    wire dn_config_rdy;

    // MN Config
    reg [159:0] mn_config_data;
    reg [31:0] mn_config_numSwitches;
    reg mn_config_en;
    wire mn_config_rdy;

    // RN Config
    reg [20:0] rn_config_data;
    reg rn_config_en;
    wire rn_config_rdy;

    // Input Data (to DN)
    reg [15:0] input_data;
    reg input_en;
    wire input_rdy;

    // Output Data (from RN)
    wire [15:0] output_data;
    reg output_en;
    wire output_rdy;

    // Instantiate the DUT
    maeriAccelerator dut (
        .CLK(CLK),
        .RST_N(RST_N),

        .isEmpty(isEmpty),
        .RDY_isEmpty(RDY_isEmpty),

        .dn_config_data(dn_config_data),
        .dn_config_en(dn_config_en),
        .dn_config_rdy(dn_config_rdy),

        .mn_config_data(mn_config_data),
        .mn_config_numSwitches(mn_config_numSwitches),
        .mn_config_en(mn_config_en),
        .mn_config_rdy(mn_config_rdy),

        .rn_config_data(rn_config_data),
        .rn_config_en(rn_config_en),
        .rn_config_rdy(rn_config_rdy),

        .input_data(input_data),
        .input_en(input_en),
        .input_rdy(input_rdy),

        .output_data(output_data),
        .output_en(output_en),
        .output_rdy(output_rdy)
    );

    // Clock Generation
    initial begin
        CLK = 0;
        forever #(CLK_PERIOD/2) CLK = ~CLK;
    end

    // Reset Generation and Initial Setup
    initial begin
        // Initialize Inputs
        RST_N = 0;
        dn_config_data = 0;
        dn_config_en = 0;
        mn_config_data = 0;
        mn_config_numSwitches = 0;
        mn_config_en = 0;
        rn_config_data = 0;
        rn_config_en = 0;
        input_data = 0;
        input_en = 0;
        output_en = 1;

        // Apply Reset
        #(CLK_PERIOD * 5);
        RST_N = 1;
        @(posedge CLK);


        // MAtrix A = [ 1 2 3 5;4 5 6 8];
        // Matrix B = [ 1 4 3 1;2 5 6 1];

        // allocate 2 vns for 4 rows of A in batch of 2 
        // vn1 : MS0,MS1,MS2,MS3
        // vn2 : MS4,MS5,MS6,MS7
       

        // then we will multicast columns of B with psum=4


        // Configure ART for 2 vns
        //         TotalBits   Operation
        // --------------------------------
        // 000         Idle (ignore inputs)
        // 010         Add two inputs
        // 011         Add two inputs and output to collection bus
        // 100         Forward left input
        // 101         Forward left input and output to bus
        // 110         Forward right input
        // 111         Forward right input and output to bus


        // DBRS CONFIGURATION

        // TotalBits   Operation
        // --------------------------------
        // 000000      Idle
        // 100010      Left addTwo (reduce left pair)
        // 001001      Right addTwo (reduce right pair)
        // 101011      Pairwise reduction (2+2)
        // 110010      Left side reduce (3 inputs)
        // 001101      Right side reduce (3 inputs)
        // 111111      Full 4-input reduction

        // Layout 
        // [20:18] SRS4
        // [17:15] SRS3
        // [14:12] SRS2
        // [11:9]  SRS1
        // [8:6]   SRS0
        // [5:0]   DBRS0
        // Level 1
        // SRS3 → inputs MS0, MS1
        // DBRS0 → inputs MS2, MS3, MS4, MS5
        // SRS4 → inputs MS6, MS7

        // art vn config
        rn_config_data = {3'd010,3'b010,3'd011,3'd011,3'd0,6'b101000};
        rn_config_en = 1;
        @(posedge CLK);
        rn_config_en = 0;
        @(posedge CLK);


        // stationary config
        mn_config_data = {STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0,STATE_FILL_STATIONARY,16'd0};
        mn_config_numSwitches = 4;
        mn_config_en = 1;
        @(posedge CLK);
        mn_config_en = 0;
        @(posedge CLK);



        // load statinoary data
        send_input(16'd1, 8'b00000001); // MS0
        send_input(16'd2, 8'b00000010); // MS1
        send_input(16'd3, 8'b00000100); // MS2
        send_input(16'd5, 8'b00001000); // MS3
        send_input(16'd4, 8'b00010000); // MS4
        send_input(16'd5, 8'b00100000); // MS5
        send_input(16'd6, 8'b01000000); // MS6
        send_input(16'd8, 8'b10000000); // MS7


        wait(isEmpty==1'b1);

        // multicast config psum=2 
        mn_config_data = {STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4,STATE_MULT_STREAMING,16'd4};
        mn_config_numSwitches = 4;
        mn_config_en = 1;
        @(posedge CLK);
        mn_config_en = 0;
        @(posedge CLK);

        // multicast data
        // col 1 [ 1 2 1 2] multicast to row 1 and row 2
        send_input(16'd1, 8'b00010001); // MS0 and MS4
        send_input(16'd4, 8'b00100010); // MS1 and MS5
        send_input(16'd3, 8'b01000100); // MS2 and MS6
        send_input(16'd1, 8'b10001000); // MS3 and MS7
        
        // col 2 [ 0 1 0 0] to row 1 and row 2
        send_input(16'd2, 8'b00010001); // MS0 and MS4
        send_input(16'd5, 8'b00100010); // MS1 and MS5
        send_input(16'd6, 8'b01000100); // MS2 and MS6
        send_input(16'd1, 8'b10001000); // MS3 and MS7
       
        
        
        wait(isEmpty==1'b1);
        
        

        #100;
        // end of simulation
        $finish;
    end

    always @(output_data) begin
        if (RST_N) begin
            $display("Time=%0t  Output changed -> %0d (0x%h)", $time, output_data, output_data);
        end
    end

endmodule