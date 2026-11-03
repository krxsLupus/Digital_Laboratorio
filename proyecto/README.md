# Slave: REMIX — starter milestone 1

This starter combines the team's 4x4 keypad scanner and servo PWM design with a simple digital note oscillator. It is intended to be the next development step, not a finished synthesizer.

## What works in this milestone

- 4x4 keypad scan and debounce, using the existing Lab 4 keypad mapping.
- Keys with returned codes 1..12 select notes C4..B4.
- `SW[0]` gates the note on/off.
- `SW[2:1]` selects wave shape: `00` square, `01` sawtooth, `10` triangle, `11` narrow pulse.
- `SW[6:3]` controls the 4-bit servo position command.
- LEDs display note/wave/gate debug state.
- Servo PWM produces a 50 Hz frame and nominal 1–2 ms pulses.

## Critical hardware caveats

1. The QSF uses `EP4CE6E22C6` because that is the device stated for this project. The source repository's older Lab 4 QSF says `EP4CE6E22C8`; check the actual FPGA marking and change the device to match the real part exactly.
2. Only the 50 MHz clock (`PIN_23`) is assigned here. The rest of the board's pin map is deliberately incomplete. Do not program the FPGA until you assign and verify every top-level I/O against the exact board schematic. Similar-looking boards can use different pinouts.
3. No DAC or speaker is available yet. `audio_sample` is internal in this first top-level, and the LEDs are debug indicators, not an audio output. Do not connect FPGA pins directly to a speaker. The LM386 is an amplifier, not a DAC.
4. Do not power a servo from an FPGA GPIO. Use a suitable separate supply for the exact servo, and connect the external supply ground to FPGA ground. Check the servo's signal-voltage requirements before connecting its signal input.
5. The keypad scanner assumes inactive column inputs read logic-high. Verify board pull-ups or add suitable external pull-ups to 3.3 V as appropriate; never expose FPGA pins to 5 V.
6. The oscillator uses a 50 MHz clock assumption in `top_remix.v`. Revisit the clock and timing constants if the board clock differs.

## Build and test with Icarus Verilog (optional but recommended)

From this directory:

```sh
iverilog -g2012 -o sim_synth src/synth_voice.v testbench/tb_synth_voice.v
vvp sim_synth

iverilog -g2012 -o sim_servo src/codificador_pos.v src/pwm_servo.v testbench/tb_pwm_servo.v
vvp sim_servo
```

Both tests should print `PASS`. A VCD trace is created for viewing in GTKWave if installed.

## Open in Quartus Prime

1. Open `quartus/Slave_REMIX.qpf`.
2. Confirm the device in **Assignments → Device** matches the chip installed on your board.
3. Compile for syntax/elaboration. You may see pin-location warnings until the full pin map is entered; this template is not ready to program to hardware yet.
4. Open Pin Planner and assign every top-level signal from the verified board pinout. Confirm I/O voltage standards and keypad electrical behavior.
5. Recompile, resolve pin and timing errors, then program only after the external wiring has been checked.

## Bench bring-up order

1. Verify clock/reset and flash a simple LED test before attaching the keypad or servo.
2. Validate keypad column/row wiring and check that codes 1..12 select the intended notes.
3. Verify the oscillator with the provided simulation before proceeding. The current LED debug output is not a substitute for an audio DAC.
4. Test the servo PWM in simulation first. For physical servo tests, use a separate properly rated supply with shared ground, and secure the servo mechanically.
5. Choose or build an 8-bit DAC/audio interface, then test its voltage range and filtering before connecting the LM386 and speaker.
6. Only after these blocks work separately, add the sequencer and display.

## Suggested next increments

- Milestone 2: improve keypad events (press/release and multiple-key behavior), add a testbench that models the row/column matrix, and test all 12 note selections.
- Milestone 3: add an envelope/gate and establish a defined audio sample update rate for the external DAC.
- Milestone 4: add an event memory and tempo counter for recording/playback of short sequences.
- Milestone 5: integrate LCD/VGA only after audio and sequencing are stable.
