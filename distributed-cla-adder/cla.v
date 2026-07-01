// ============================================================
//  Distributed CLA Adder — per-bit GP cell architecture
//
//  Core idea: every bit owns an isolated gp_cell module that
//  produces exactly one G and one P signal. Those signals are
//  collected as buses and handed to a single carry_lookahead_network
//  that resolves all carries in parallel. Sum is then computed
//  per-bit from the resolved carry.
//
//  This keeps each stage independently testable and naturally
//  pipeline-able (insert a register between gp_cells and the
//  carry network for higher clock frequencies).
// ============================================================


// ------------------------------------------------------------
//  Module 1: gp_cell
//  One instance per bit. Just two gates — nothing more.
//  Intentionally NOT inlined so it appears as a real unit
//  in synthesis and simulation hierarchy.
// ------------------------------------------------------------
module gp_cell (
    input  wire a,
    input  wire b,
    output wire g,   // Generate: this bit produces a carry on its own
    output wire p    // Propagate: this bit will pass a carry through
);
    assign g = a & b;
    assign p = a ^ b;
endmodule


// ------------------------------------------------------------
//  Module 2: carry_lookahead_network
//  Receives G[N-1:0] and P[N-1:0] from all gp_cells.
//  Computes C[1] through C[N] (carry INTO each bit position
//  and the final carry-out) without any ripple dependency.
//
//  C[i+1] = G[i] | (P[i] & C[i])  — unrolled for all bits
//
//  Each carry is expressed directly in terms of G, P, and C_in
//  only — no carry feeds from another carry expression inside
//  this block. That is the lookahead property.
// ------------------------------------------------------------
module carry_lookahead_network #(
    parameter N = 8
)(
    input  wire [N-1:0] g,       // Generate bus from all gp_cells
    input  wire [N-1:0] p,       // Propagate bus from all gp_cells
    input  wire         c_in,    // External carry-in (bit 0's carry)
    output wire [N:0]   c        // c[0]=c_in, c[1..N] are lookahead carries
);
    // c[0] is just c_in — the carry into the LSB
    assign c[0] = c_in;

    // Each carry is written out as a flat boolean expression.
    // The generate block only iterates the BIT INDEX — it does
    // NOT nest carry expressions inside each other. Each c[i+1]
    // is independently expressed in terms of g, p, and c[0].
    //
    // For a 4-bit example this expands to:
    //   c[1] = g[0] | (p[0] & c[0])
    //   c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0])
    //   c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0])
    //        |         (p[2] & p[1] & p[0] & c[0])
    //   ...
    // Written as a loop for N generality:

    // For carry bit i+1, the full lookahead expression is:
    //
    //   c[i+1] = G[i]
    //          | P[i] & G[i-1]
    //          | P[i] & P[i-1] & G[i-2]
    //          | ...
    //          | P[i] & P[i-1] & ... & P[0] & c_in
    //
    // Each term is a running AND of P's from bit i down to bit j,
    // terminated by either G[j-1] or c_in at j=0.
    // We build the running P-product top-down (i to j) so each
    // step only depends on the previously accumulated value —
    // no forward references, no circular dependencies.

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : carry_bit

            // pp[j] = P[i] & P[i-1] & ... & P[j]
            wire [i:0] pp;

            // Seed at the top
            assign pp[i] = p[i];

            // Extend downward — each entry only reads pp[j+1] which is
            // already fully assigned before this iteration
            for (j = i-1; j >= 0; j = j - 1) begin : pp_chain
                assign pp[j] = pp[j+1] & p[j];
            end

            // term[j] = pp[j] & G[j-1]   for j > 0  (P chain ended by a generate)
            // term[0] = pp[0] & c_in                 (P chain reached all the way back)
            wire [i:0] term;

            for (j = 0; j <= i; j = j + 1) begin : terms
                if (j == 0)
                    assign term[0] = pp[0] & c_in;
                else
                    assign term[j] = pp[j] & g[j-1];
            end

            // Final carry: own generate OR any propagation term
            assign c[i+1] = g[i] | (|term);
        end
    endgenerate
endmodule


// ------------------------------------------------------------
//  Module 3: distributed_cla_adder  (top level)
//
//  Instantiates:
//    - N copies of gp_cell (one per bit, explicitly named)
//    - 1 copy of carry_lookahead_network
//
//  Then computes sum[i] = p[i] ^ c[i]
//  (P[i] = A[i]^B[i] already, so XOR-ing with carry gives sum)
// ------------------------------------------------------------
module distributed_cla_adder #(
    parameter N = 8
)(
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    input  wire         c_in,
    output wire [N-1:0] sum,
    output wire         c_out
);

    // ---- Stage 1: per-bit G/P generation ----
    // Each bit gets its own named gp_cell instance.
    // These are NOT inlined — they appear as separate cells
    // in the synthesized netlist and simulation hierarchy.

    wire [N-1:0] g;   // Collected generate signals
    wire [N-1:0] p;   // Collected propagate signals

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gp_stage
            gp_cell u_gp (
                .a  (a[i]),
                .b  (b[i]),
                .g  (g[i]),
                .p  (p[i])
            );
        end
    endgenerate

    // ---- Stage 2: shared carry lookahead network ----
    // One instance receives all G/P buses and resolves
    // every carry simultaneously.

    wire [N:0] c;   // c[0]=c_in, c[N]=c_out

    carry_lookahead_network #(.N(N)) u_cln (
        .g    (g),
        .p    (p),
        .c_in (c_in),
        .c    (c)
    );

    // ---- Stage 3: per-bit sum computation ----
    // sum[i] = A[i] XOR B[i] XOR C[i]
    //        = P[i]          XOR C[i]   (reuse P from gp_cell)

    generate
        for (i = 0; i < N; i = i + 1) begin : sum_stage
            assign sum[i] = p[i] ^ c[i];
        end
    endgenerate

    assign c_out = c[N];

endmodule


