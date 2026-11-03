.PHONY: test test-synth test-servo clean

test: test-synth test-servo

test-synth:
	iverilog -g2012 -o sim_synth src/synth_voice.v testbench/tb_synth_voice.v
	vvp sim_synth

test-servo:
	iverilog -g2012 -o sim_servo src/codificador_pos.v src/pwm_servo.v testbench/tb_pwm_servo.v
	vvp sim_servo

clean:
	rm -f sim_synth sim_servo *.vcd
