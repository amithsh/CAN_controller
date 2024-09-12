module bit_timing_module_params(
    
    input wire [31:0]config_data; //not currently in the use we can make use of this after
    //using the config_data user can give the data of the below parameters in the tb so that we can assign them to the below segments using the bit assigning


    // below are the parameters we defined here to make use of them in the timing_module
    output reg [7:0] phase_seg1;//phase segment-1
    output reg [7:0] phase_seg2; //phase segment-2
    output reg [7:0] prop_seg; //propagation segment
    output reg [7:0] sync_seg;//syncronization segment;
)


initial begin
    phase_seg1 = 'd4;
    phase_seg2 = 'd4;
    prop_seg = 'd8;
    sync_seg = 'd1;

end


endmodule