/*
 * Proyecto VGA Dual-Mode: 
 * - Modo 0: Logo cuadrado 128x128
 * - Modo 1: Logo rectangular 128x40 (estilo DVD)
 * 
 * ui_in[0]: cfg_tile - Habilita/deshabilita el tile
 * ui_in[1]: cfg_color - Selecciona color dinámico o blanco
 * ui_in[2]: cfg_mode - 0=cuadrado 128x128, 1=rectangular 128x40
 */

`default_nettype none

parameter DISPLAY_WIDTH = 640;
parameter DISPLAY_HEIGHT = 480;
parameter LOGO_SIZE_SQUARE = 128;
parameter LOGO_WIDTH_RECT = 128;
parameter LOGO_HEIGHT_RECT = 40;

`define COLOR_WHITE 3'd7

module tt_um_vga_dual_mode (
    input  wire [7:0] ui_in,    // ui_in[2]: selector de modo
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // VGA signals
  wire hsync, vsync;
  reg [1:0] R, G, B;
  wire video_active;
  wire [9:0] pix_x, pix_y;

  // Configuración
  wire cfg_tile = ui_in[0];
  wire cfg_color = ui_in[1];
  wire cfg_mode = ui_in[2];  // 0=128x128, 1=128x40

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe = 0;
  wire _unused_ok = &{ena, ui_in[7:3], uio_in};

  // Parámetros dinámicos según modo
  wire [9:0] logo_width = cfg_mode ? LOGO_WIDTH_RECT : LOGO_SIZE_SQUARE;
  wire [9:0] logo_height = cfg_mode ? LOGO_HEIGHT_RECT : LOGO_SIZE_SQUARE;
  
  // Variables de posición y dirección
  reg [9:0] logo_left;
  reg [9:0] logo_top;
  reg dir_x;
  reg dir_y;
  reg [2:0] color_index;
  reg [9:0] prev_y;
  
  // Detección de cambio de modo
  reg cfg_mode_prev;
  wire mode_changed = cfg_mode != cfg_mode_prev;

  // Calcular offsets (evita part-select sobre expresión)
  wire [9:0] x_offset = pix_x - logo_left;
  wire [9:0] y_offset = pix_y - logo_top;
  
  // Selección de bits de dirección según modo
  wire [6:0] rom_x;
  wire [6:0] rom_y_square;
  wire [5:0] rom_y_rect;
  
  assign rom_x = x_offset[6:0];
  assign rom_y_square = y_offset[6:0];  // 7 bits para 128
  assign rom_y_rect = y_offset[5:0];    // 6 bits para 40

  // Señales de píxel de ambas ROMs
  wire pixel_square, pixel_rect;
  wire pixel_value = cfg_mode ? pixel_rect : pixel_square;
  
  // Lógica de límites adaptativa
  wire x_in_range = (pix_x >= logo_left) && (pix_x < logo_left + logo_width);
  wire y_in_range = (pix_y >= logo_top) && (pix_y < logo_top + logo_height);
  wire logo_pixels = cfg_tile || (x_in_range && y_in_range);

  // Instancias de ROMs duales
  bitmap_rom_square rom_square (
      .x(rom_x),
      .y(rom_y_square),
      .pixel(pixel_square)
  );
  
  bitmap_rom_rect rom_rect (
      .x(rom_x),
      .y(rom_y_rect),
      .pixel(pixel_rect)
  );

  // Generador de sincronización VGA
  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // Palette
  wire [5:0] color;
  
  palette palette_inst (
      .color_index(cfg_color ? color_index : `COLOR_WHITE),
      .rrggbb(color)
  );

  // Lógica RGB
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
    end else begin
      R <= 0;
      G <= 0;
      B <= 0;
      if (video_active && logo_pixels) begin
        R <= pixel_value ? color[5:4] : 0;
        G <= pixel_value ? color[3:2] : 0;
        B <= pixel_value ? color[1:0] : 0;
      end
    end
  end

  // Lógica de rebote robusta con ajuste automático al cambiar modo
  always @(posedge clk) begin
    // Detectar cambio de modo
    cfg_mode_prev <= cfg_mode;
    
    if (~rst_n) begin
      // Reset inicial
      logo_left <= 200;
      logo_top <= 200;
      dir_x <= 1;
      dir_y <= 0;
      color_index <= 0;
      prev_y <= 0;
    end else if (mode_changed) begin
      // ============================================
      // AJUSTE ROBUSTO - SIEMPRE se ejecuta al cambiar modo
      // ============================================
      
      // 1. Ajustar posición horizontal si sobresale
      if (logo_left + logo_width > DISPLAY_WIDTH) begin
        logo_left <= DISPLAY_WIDTH - logo_width;
      end
      
      // 2. Ajustar posición vertical si sobresale
      if (logo_top + logo_height > DISPLAY_HEIGHT) begin
        logo_top <= DISPLAY_HEIGHT - logo_height;
      end
      
      // 3. Ajustar dirección de rebote horizontal
      if (logo_left == 0) begin
        dir_x <= 1;  // Rebota a la derecha
      end
      if (logo_left + logo_width == DISPLAY_WIDTH) begin
        dir_x <= 0;  // Rebota a la izquierda
      end
      
      // 4. Ajustar dirección de rebote vertical
      if (logo_top == 0) begin
        dir_y <= 1;  // Rebota hacia abajo
      end
      if (logo_top + logo_height == DISPLAY_HEIGHT) begin
        dir_y <= 0;  // Rebota hacia arriba
      end
      
      // 5. Cambiar color para feedback visual (siempre al cambiar modo)
      color_index <= color_index + 1;
      
    end else begin
      // ============================================
      // LÓGICA DE REBOTE NORMAL
      // ============================================
      prev_y <= pix_y;
      if (pix_y == 0 && prev_y != pix_y) begin
        logo_left <= logo_left + (dir_x ? 1 : -1);
        logo_top  <= logo_top + (dir_y ? 1 : -1);
        
        // Rebote horizontal
        if (logo_left == 0 && !dir_x) begin
          dir_x <= 1;
          color_index <= color_index + 1;
        end
        if (logo_left + logo_width == DISPLAY_WIDTH && dir_x) begin
          dir_x <= 0;
          color_index <= color_index + 1;
        end
        
        // Rebote vertical
        if (logo_top == 0 && !dir_y) begin
          dir_y <= 1;
          color_index <= color_index + 1;
        end
        if (logo_top + logo_height == DISPLAY_HEIGHT && dir_y) begin
          dir_y <= 0;
          color_index <= color_index + 1;
        end
      end
    end
  end

endmodule