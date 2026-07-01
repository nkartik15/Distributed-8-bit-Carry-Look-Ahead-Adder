// ------------------------------------------------------------
//  Testbench — 10 hand-picked cases that each stress one
//  distinct behaviour of the distributed CLA architecture.
//
//  Test map:
//   T01  zero + zero,         no  cin  → pure zero path
//   T02  zero + zero,         cin=1    → cin ripples to sum LSB only
//   T03  all-ones + 1,        no  cin  → full carry chain, overflow
//   T04  all-ones + all-ones, cin=1    → max overflow (FF+FF+1)
//   T05  alternating 0xAA+0x55, no cin → every gp_cell generates P, no G
//   T06  alternating 0xAA+0x55, cin=1  → same but cin propagates all way through
//   T07  0xF0 + 0x0F,         no  cin  → upper/lower nibble isolation
//   T08  0x0F + 0x01,         no  cin  → carry generated in low nibble only
//   T09  0x80 + 0x80,         no  cin  → MSB generate, single carry-out
//   T10  random-ish 0x6C+0x4B, cin=1  → mixed G/P across all cells
// ------------------------------------------------------------

module tb_distributed_cla_adder;

    localparam N = 8;

    reg  [N-1:0] a, b;
    reg          cin;
    wire [N-1:0] sum;
    wire         cout;

    distributed_cla_adder #(.N(N)) dut (
        .a(a), .b(b), .c_in(cin), .sum(sum), .c_out(cout)
    );

    // Expected result is N+1 bits wide to capture carry-out
    reg [N:0] expected;
    integer   errors = 0;

    // Apply inputs, wait for combinational settle, then check
    task apply_and_check;
        input [N-1:0]  ta, tb;
        input          tcin;
        input [8*32:1] label;
        begin
            a   = ta;
            b   = tb;
            cin = tcin;
            #5;
            expected = ta + tb + tcin;
            if ({cout, sum} !== expected) begin
                $display("FAIL  %-30s | a=0x%02h b=0x%02h cin=%0b | got=0x%03h exp=0x%03h",
                          label, ta, tb, tcin, {cout,sum}, expected);
                errors = errors + 1;
            end else begin
                $display("PASS  %-30s | a=0x%02h b=0x%02h cin=%0b | result=0x%03h",
                          label, ta, tb, tcin, {cout,sum});
            end
        end
    endtask

    initial begin
        $display("=== Distributed CLA Adder — 10-case testbench ===\n");

        apply_and_check(8'h00, 8'h00, 0, "T01 zero+zero");
        apply_and_check(8'h00, 8'h00, 1, "T02 zero+zero+cin");
        apply_and_check(8'hFF, 8'h01, 0, "T03 full carry chain");
        apply_and_check(8'hFF, 8'hFF, 1, "T04 max overflow");
        apply_and_check(8'hAA, 8'h55, 0, "T05 all-propagate no cin");
        apply_and_check(8'hAA, 8'h55, 1, "T06 all-propagate cin=1");
        apply_and_check(8'hF0, 8'h0F, 0, "T07 nibble isolation");
        apply_and_check(8'h0F, 8'h01, 0, "T08 low-nibble carry only");
        apply_and_check(8'h80, 8'h80, 0, "T09 MSB generate");
        apply_and_check(8'h6C, 8'h4B, 1, "T10 mixed G/P pattern");

        $display("\n=== %0d / 10 passed ===", 10 - errors);
        if (errors == 0)
            $display("ALL PASSED");
        else
            $display("%0d FAILURE(S) DETECTED", errors);

        $finish;
    end

endmodule

