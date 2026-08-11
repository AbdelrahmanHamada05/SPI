
vlib work
vmap work work

vlog ALSU.v
vlog ALSU_tb.v

vsim -voptargs=+acc work.ALSU_tb

add wave *
run -all