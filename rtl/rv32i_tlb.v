module rv32i_tlb (
    input  wire        clk,
    input  wire        rst,
    input  wire        lookup_valid,
    input  wire [19:0] lookup_vpn,
    output reg         tlb_hit,
    output reg  [21:0] tlb_ppn,
    input  wire        write_enable,
    input  wire [19:0] write_vpn,
    input  wire [21:0] write_ppn,
    input  wire        flush_all,
    output wire [31:0] tlb_hit_count,
    output wire [31:0] tlb_miss_count,
    output wire [31:0] tlb_access_count
);

    integer i;

    reg        valid_entry [0:3];
    reg [19:0] vpn_entry   [0:3];
    reg [21:0] ppn_entry   [0:3];
    reg [1:0]  next_write_index;
    reg [31:0] hit_count;
    reg [31:0] miss_count;
    reg [31:0] access_count;

    assign tlb_hit_count = hit_count;
    assign tlb_miss_count = miss_count;
    assign tlb_access_count = access_count;

    always @(*) begin
        tlb_hit = 1'b0;
        tlb_ppn = 22'd0;

        for (i = 0; i < 4; i = i + 1) begin
            if (valid_entry[i] && (vpn_entry[i] == lookup_vpn)) begin
                tlb_hit = 1'b1;
                tlb_ppn = ppn_entry[i];
            end
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            next_write_index <= 2'd0;
            hit_count <= 32'd0;
            miss_count <= 32'd0;
            access_count <= 32'd0;

            for (i = 0; i < 4; i = i + 1) begin
                valid_entry[i] <= 1'b0;
                vpn_entry[i] <= 20'd0;
                ppn_entry[i] <= 22'd0;
            end
        end else begin
            if (lookup_valid) begin
                access_count <= access_count + 32'd1;

                if (tlb_hit) begin
                    hit_count <= hit_count + 32'd1;
                end else begin
                    miss_count <= miss_count + 32'd1;
                end
            end

            if (flush_all) begin
                next_write_index <= 2'd0;

                for (i = 0; i < 4; i = i + 1) begin
                    valid_entry[i] <= 1'b0;
                    vpn_entry[i] <= 20'd0;
                    ppn_entry[i] <= 22'd0;
                end
            end else if (write_enable) begin
                valid_entry[next_write_index] <= 1'b1;
                vpn_entry[next_write_index] <= write_vpn;
                ppn_entry[next_write_index] <= write_ppn;
                next_write_index <= next_write_index + 2'd1;
            end
        end
    end

endmodule
