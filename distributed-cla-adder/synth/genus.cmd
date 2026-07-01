# Cadence Genus(TM) Synthesis Solution, Version 21.14-s082_1, built Jun 23 2022 14:32:08

# Date: Thu May 14 06:47:56 2026
# Host: cad97 (x86_64 w/Linux 4.18.0-425.3.1.el8.x86_64) (16cores*24cpus*1physical cpu*13th Gen Intel(R) Core(TM) i7-13700 30720KB)
# OS:   Red Hat Enterprise Linux release 8.7 (Ootpa)

read_lib /home/install/cad/slow.lib
read_hdl cla.v
elaborate
set_db syn_generic_effort medium
set_db syn_map_effort     medium
set_db syn_opt_effort     medium
syn_generic
syn_map
syn_opt
report area
report power
report gates
report timing -unconstrained
