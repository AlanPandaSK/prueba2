# VGA Dual-Mode DVD Screensaver
 
## How it works
 
This project implements a **dual-mode DVD-style bouncing logo** on a VGA monitor. It supports two logo modes: a square 128×128 bitmap (UACJ university logo) or a rectangular 128×40 bitmap (UACJ IIT logo). The design is written in Verilog and targets the Tiny Tapeout ASIC shuttle.
 
The system is composed of five main blocks: a VGA sync generator, dual bitmap ROMs (square and rectangular), mode selection logic, bouncing logic with position registers, a color palette, and an RGB output multiplexer. The diagram below shows the overall architecture.
 
 
_**Figure 1.** Block diagram of the dual-mode VGA screensaver system._
 
### Block description
 
- **hvsync_generator** – Generates the HSync and VSync timing signals required for a 640×480 @ 60 Hz VGA display. It also produces the current pixel coordinates (`hpos`, `vpos`) and an active video flag (`display_on`).
- **Dual Bitmap ROMs** – Two independent ROM modules:
  - `bitmap_rom_square` – 2,048-byte ROM (128×128 pixels, 16 bytes per row) storing the square UACJ university logo pattern
  - `bitmap_rom_rect` – 640-byte ROM (40 rows × 16 bytes per row) storing the 128×40 UACJ IIT logo
  - Both ROMs use 1 bit per pixel: `1` for logo foreground, `0` for background
  - The active ROM is selected by `cfg_mode`
- **Mode Selection Logic** – Dynamically switches between square and rectangular modes using `cfg_mode` input. When the mode changes, the system automatically:
  - Adjusts logo position to fit within screen boundaries
  - Corrects direction vectors to prevent stuck states
  - Increments the color index for visual feedback
- **Bouncing Logic & Position Registers** – Maintains the current top-left corner position of the active logo (`logo_left`, `logo_top`) and the direction of movement (`dir_x`, `dir_y`). On each frame (detected during vertical blanking at pixel Y=0), the position updates by one pixel. When the logo reaches a screen edge, it bounces and increments the color index.
- **palette** – An 8-entry color palette (6-bit RGB, 2 bits per channel). The logo color cycles through the palette on each bounce. The `cfg_color` input selects between color mode and monochrome (white on black).
- **RGB Mux & Output Registers** – Combines the pixel value (from the selected ROM), the selected color (from palette), and the video timing to produce the final 2-bit per channel RGB output. The result is latched in registers before being sent to the output pins.
### Configuration inputs
 
The design accepts five configuration inputs via the `ui_in[7:0]` pins:
 
| Pin        | Name        | Description                                                     |
|------------|-------------|-----------------------------------------------------------------|
| `ui_in[0]` | `cfg_tile`  | Debug mode: fill the entire screen with the selected logo pattern |
| `ui_in[1]` | `cfg_color` | 0 = monochrome (white on black), 1 = color palette              |
| `ui_in[2]` | `cfg_mode`  | 0 = square UACJ logo (128×128), 1 = rectangular UACJ IIT logo (128×40) |
| `ui_in[3]` | `unused`    | Reserved for future use                                         |
| `ui_in[4]` | `unused`    | Reserved for future use                                         |
 
> [!NOTE]
> The VGA output follows the **TinyVGA PMOD** pin mapping:
> `uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}`.
> Connect directly to a TinyVGA PMOD or a compatible VGA DAC.
 
---
 
## How to test
 
### Simulation testing (CocoTB)
 
The project includes a CocoTB testbench that verifies the basic functionality. Due to the complexity of VGA simulation, the default test is configured to pass trivially. For full verification, you can implement the following test procedure:
 
1. **Navigate to the `test` folder** and ensure `test.py` and `Makefile` are present.
2. **Run the simulation** using:
   ```bash
   make
   ```
 
3. **Expected behaviour** (if you implement full testing):
   - The testbench should generate VGA timing signals and verify that the active logo bounces correctly within the 640×480 screen boundaries
   - On each bounce, the simulation should check that:
     - The direction toggles (horizontal or vertical)
     - The color index increments by 1
   - The selected bitmap ROM output should match the expected pattern for the current mode
   - Mode switching should correctly reposition the logo and maintain valid bounds
### Hardware testing (FPGA or final chip)
 
#### Required equipment
- VGA monitor (supports 640×480 @ 60 Hz)
- TinyVGA PMOD
- Switches for configuration inputs (recommended for `cfg_tile`, `cfg_color`, `cfg_mode`)
- 25.175 MHz clock source (provided by the Tiny Tapeout harness)
#### Test procedure
 
**1. Basic functionality test (square mode – UACJ logo)**
 
Set `cfg_mode = 0` (square). Connect the TinyVGA PMOD to your board and to the monitor. Apply power and reset. You should observe:
 
- The **UACJ university logo** (128×128 square) bouncing diagonally across the screen
- The logo changes colour each time it hits a wall (cycles through 8 colours)
- Background remains black
**2. Basic functionality test (rectangular mode – UACJ IIT logo)**
 
Set `cfg_mode = 1` (rectangular). You should observe:
 
- The **UACJ IIT logo** (128×40 rectangle) bouncing diagonally across the screen
- Logo changes colour on each wall hit
- Same bounce behaviour with different aspect ratio
**3. Mode switching test**
 
Toggle `cfg_mode` while the logo is moving. The system should:
 
- Immediately switch between the UACJ university logo and the UACJ IIT logo
- Automatically reposition the logo if it would extend beyond screen boundaries
- Maintain continuous motion without glitches or stuck states
- Increment colour index on mode change for visual feedback
**4. Configuration input tests**
 
Apply logic levels to the `ui_in[1:0]` pins and observe the behaviour:
 
| Input combination | Expected behaviour |
|-------------------|---------------------|
| `cfg_tile = 1`    | The entire screen fills with the selected logo pattern (debug mode) |
| `cfg_color = 0`   | Logo becomes white, background becomes black (monochrome mode) |
| `cfg_color = 1`   | Logo cycles through 8 colours on each bounce |
| `cfg_mode = 0`    | Square UACJ university logo (128×128) active |
| `cfg_mode = 1`    | Rectangular UACJ IIT logo (128×40) active |
 
**5. Boundary testing**
 
Monitor the logo position as it approaches screen edges. For each mode:
 
**Square mode (UACJ logo – 128×128):**
- Left edge (X = 0) should cause a horizontal bounce
- Right edge (X = 640 - 128 = 512) should cause a horizontal bounce
- Top edge (Y = 0) should cause a vertical bounce
- Bottom edge (Y = 480 - 128 = 352) should cause a vertical bounce
**Rectangular mode (UACJ IIT logo – 128×40):**
- Left edge (X = 0) should cause a horizontal bounce
- Right edge (X = 640 - 128 = 512) should cause a horizontal bounce
- Top edge (Y = 0) should cause a vertical bounce
- Bottom edge (Y = 480 - 40 = 440) should cause a vertical bounce
**6. Mode transition boundary testing**
 
While the logo is near an edge, toggle `cfg_mode`. Verify that:
- The logo never extends beyond display boundaries after mode change
- The direction vectors remain valid (logo doesn't get stuck moving out of bounds)
- The system recovers gracefully even if mode toggles rapidly
### Expected results
 
After successful testing, the system should:
- Display the correct UACJ university logo (square mode) and UACJ IIT logo (rectangular mode)
- Bounce reliably off all four screen edges in both modes
- Cycle through 8 distinct colours on wall hits (when `cfg_color = 1`)
- Switch seamlessly between both logo modes on demand
- Maintain correct positioning after mode changes
- Respond correctly to all configuration inputs
- Maintain stable VGA sync (no flickering or rolling image)
---
 
## External hardware
 
### Required for operation
 
| Component | Purpose | Specifications |
|-----------|---------|----------------|
| **VGA monitor** | Display the bouncing logo | 640×480 @ 60 Hz (supports standard VGA timings) |
| **VGA cable** | Connect the board to monitor | Male DB-15 to male DB-15 |
| **TinyVGA PMOD** | Convert digital outputs to analog VGA signals | Uses 6 digital lines (2 bits per colour) + HSync + VSync |
| **Clock source** | Drive the VGA timing | 25.175 MHz (provided by Tiny Tapeout harness) |
 
### Optional for testing
 
| Component | Purpose |
|-----------|---------|
| **DIP switches** | Manually control `cfg_tile`, `cfg_color`, and `cfg_mode` inputs |
| **Oscilloscope** | Verify RGB output levels |
| **VGA capture card** | Record and analyse frame-by-frame behaviour |
 
---
 
## Design notes
 
### Mode switching robustness
 
The design includes a robust mode transition handler that automatically:
1. Repositions the logo if it extends beyond the new display bounds
2. Corrects direction vectors to prevent out-of-bounds movement
3. Provides visual feedback by incrementing the colour index
This ensures smooth transitions even when switching modes near screen edges.
 
### Resource utilisation
 
| Component | Memory size | Address bits |
|-----------|-------------|--------------|
| Square ROM (UACJ logo) | 2,048 bytes | 11 bits (7+4) |
| Rectangular ROM (UACJ IIT logo) | 640 bytes | 10 bits (6+4) |
| Total | 2,688 bytes | - |
 
### Palette colours
 
The palette provides 8 colours (6-bit RGB, 2 bits per channel):
 
| Index | Colour | RGB (2 bits per channel) |
|-------|--------|--------------------------|
| 0 | Cyan | 00 10 11 |
| 1 | Pink | 11 01 10 |
| 2 | Green | 10 11 01 |
| 3 | Orange | 11 10 00 |
| 4 | Purple | 11 00 11 |
| 5 | Yellow | 01 11 11 |
| 6 | Red | 11 00 01 |
| 7 | White | 11 11 11 |
