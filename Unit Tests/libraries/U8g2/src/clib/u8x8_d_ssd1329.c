/*

  u8x8_d_ssd1329.c

  Universal 8bit Graphics Library (https://github.com/olikraus/u8g2/)

  Copyright (c) 2016, olikraus@gmail.com
  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, 
  are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this list 
    of conditions and the following disclaimer.
    
  * Redistributions in binary form must reproduce the above copyright notice, this 
    list of conditions and the following disclaimer in the documentation and/or other 
    materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  
  
*/


#include "u8x8.h"



static const uint8_t u8x8_d_ssd1329_128x96_noname_init_seq[] = {
    
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  
  
  U8X8_C(0x0ae),		                /* display off */
  U8X8_CA(0x0b3, 0x091),		/* set display clock divide ratio/oscillator frequency (set clock as 135 frames/sec) */			
  U8X8_CA(0x0a8, 0x05f),		/* multiplex ratio: 0x03f * 1/64 duty - changed by CREESOO, acc. to datasheet, 100317*/ 
  U8X8_CA(0x0a2, 0x000),		/* display offset, shift mapping ram counter */
  U8X8_CA(0x0a1, 0x000),		/* display start line */
  U8X8_CA(0x0ad, 0x002),		/* master configuration: disable embedded DC-DC, enable internal VCOMH */
  U8X8_CA(0x0a0, 0x052),		/* remap configuration, horizontal address increment (bit 2 = 0), enable nibble remap (upper nibble is left, bit 1 = 1) */
  U8X8_C(0x086),				/* full current range (0x084, 0x085, 0x086) */
#ifdef removed
  U8X8_C(0x0b8),				/* set gray scale table */
    U8X8_A(1),				/* */
    U8X8_A(5),				/* */
    U8X8_A(10),				/* */
    U8X8_A(14),				/* */
    U8X8_A(19),				/* */
    U8X8_A(23),				/* */
    U8X8_A(28),				/* */
    U8X8_A(32),				/* */
    U8X8_A(37),				/* */
    U8X8_A(41),				/* */
    U8X8_A(46),				/* */
    U8X8_A(50),				/* */
    U8X8_A(55),				/* */
    U8X8_A(59),				/* */
    U8X8_A(63),				/* */
#endif 

  U8X8_C(0x0b7),				/* set default gray scale table */
    
  U8X8_CA(0x081, 0x070),		/* contrast, brightness, 0..128 */
  U8X8_CA(0x0b2, 0x051),		/* frame frequency (row period) */
  U8X8_CA(0x0b1, 0x055),                    /* phase length */
  U8X8_CA(0x0bc, 0x010),                    /* pre-charge voltage level */
  U8X8_CA(0x0b4, 0x002),                    /* set pre-charge compensation level (not documented in the SDD1325 datasheet, but used in the NHD init seq.) */
  U8X8_CA(0x0b0, 0x028),                    /* enable pre-charge compensation (not documented in the SDD1325 datasheet, but used in the NHD init seq.) */
  U8X8_CA(0x0be, 0x01c),                     /* VCOMH voltage */
  U8X8_CA(0x0bf, 0x002|0x00d),           /* VSL voltage level (not documented in the SDD1325 datasheet, but used in the NHD init seq.) */
  U8X8_C(0x0a4),				/* normal display mode */
    
  U8X8_CA(0x023, 0x003),		/* graphics accelleration: fill pixel */
    
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};

static const uint8_t u8x8_d_ssd1329_128x96_nhd_powersave0_seq[] = {
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  U8X8_C(0x0af),		                /* display on */
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};

static const uint8_t u8x8_d_ssd1329_128x96_nhd_powersave1_seq[] = {
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  U8X8_C(0x0ae),		                /* display off */
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};

static const uint8_t u8x8_d_ssd1329_128x96_nhd_flip0_seq[] = {
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  U8X8_CA(0x0a0, 0x052),		/* remap */
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};

static const uint8_t u8x8_d_ssd1329_128x96_nhd_flip1_seq[] = {
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  U8X8_CA(0x0a0, 0x041),		/* remap */
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};


/*
  input:
    one tile (8 Bytes)
  output:
    Tile for ssd1329 (32 Bytes)
*/

static uint8_t u8x8_ssd1329_8to32_dest_buf[32];

static uint8_t *u8x8_ssd1329_8to32(U8X8_UNUSED u8x8_t *u8x8, uint8_t *ptr)
{
  uint8_t v;
  uint8_t a,b;
  uint8_t i, j;
  uint8_t *dest;
  
  for( j = 0; j < 4; j++ )
  {
    dest = u8x8_ssd1329_8to32_dest_buf;
    dest += j;
    a =*ptr;
    ptr++;
    b = *ptr;
    ptr++;
    for( i = 0; i < 8; i++ )
    {
      v = 0;
      if ( a&1 ) v |= 0xf0;
      if ( b&1 ) v |= 0x0f;
      *dest = v;
      dest+=4;
      a >>= 1;
      b >>= 1;
    }
  }
  
  return u8x8_ssd1329_8to32_dest_buf;
}




static uint8_t u8x8_d_ssd1329_128x96_generic(u8x8_t *u8x8, uint8_t msg, uint8_t arg_int, void *arg_ptr)
{
  uint8_t x, y, c;
  uint8_t *ptr;
  switch(msg)
  {
    /* handled by the calling function
    case U8X8_MSG_DISPLAY_SETUP_MEMORY:
      u8x8_d_helper_display_setup_memory(u8x8, &u8x8_ssd1329_128x96_nhd_display_info);
      break;
    */
    case U8X8_MSG_DISPLAY_INIT:
      u8x8_d_helper_display_init(u8x8);
      u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_noname_init_seq);    
      break;
    case U8X8_MSG_DISPLAY_SET_POWER_SAVE:
      if ( arg_int == 0 )
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_nhd_powersave0_seq);
      else
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_nhd_powersave1_seq);
      break;
    case U8X8_MSG_DISPLAY_SET_FLIP_MODE:
      if ( arg_int == 0 )
      {
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_nhd_flip0_seq);
	u8x8->x_offset = u8x8->display_info->default_x_offset;
      }
      else
      {
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_nhd_flip1_seq);
	u8x8->x_offset = u8x8->display_info->flipmode_x_offset;
      }
      break;
#ifdef U8X8_WITH_SET_CONTRAST
    case U8X8_MSG_DISPLAY_SET_CONTRAST:
      u8x8_cad_StartTransfer(u8x8);
      u8x8_cad_SendCmd(u8x8, 0x081 );
      u8x8_cad_SendArg(u8x8, arg_int );	/* ssd1329 has range from 0 to 255 */
      u8x8_cad_EndTransfer(u8x8);
      break;
#endif
    case U8X8_MSG_DISPLAY_DRAW_TILE:
      u8x8_cad_StartTransfer(u8x8);
      x = ((u8x8_tile_t *)arg_ptr)->x_pos;
      x *= 4;
      
      y = (((u8x8_tile_t *)arg_ptr)->y_pos);
      
      y *= 8;
      y += u8x8->x_offset;		/* x_offset is used as y offset for the ssd1329 */
    
      
      do
      {
	c = ((u8x8_tile_t *)arg_ptr)->cnt;
	ptr = ((u8x8_tile_t *)arg_ptr)->tile_ptr;

	do
	{
	  if ( ptr[0] | ptr[1] | ptr[2] | ptr[3] | ptr[4] | ptr[5] | ptr[6] | ptr[7] )
	  {
	    /* draw the tile if pattern is not zero for all bytes */
	    u8x8_cad_SendCmd(u8x8, 0x015 );	/* set column address */
	    u8x8_cad_SendArg(u8x8, x );	/* start */
	    u8x8_cad_SendArg(u8x8, x+3 );	/* end */

	    u8x8_cad_SendCmd(u8x8, 0x075 );	/* set row address */
	    u8x8_cad_SendArg(u8x8, y);
	    u8x8_cad_SendArg(u8x8, y+7);
	    
	    
	    u8x8_cad_SendData(u8x8, 32, u8x8_ssd1329_8to32(u8x8, ptr));
	  }
	  else
	  {
	    /* tile is empty, use the graphics acceleration command */
	    /* are this really available on the SSD1329??? */
	    u8x8_cad_SendCmd(u8x8, 0x024 );	// draw rectangle
	    u8x8_cad_SendArg(u8x8, x );	
	    u8x8_cad_SendArg(u8x8, y );	
	    u8x8_cad_SendArg(u8x8, x+3 );	
	    u8x8_cad_SendArg(u8x8, y+7 );	
	    u8x8_cad_SendArg(u8x8, 0 );	// clear	    
	  }
	  ptr += 8;
	  x += 4;
	  c--;
	} while( c > 0 );
	
	//x += 4;
	arg_int--;
      } while( arg_int > 0 );
      
      u8x8_cad_EndTransfer(u8x8);
      break;
    default:
      return 0;
  }
  return 1;
}


static const u8x8_display_info_t u8x8_ssd1329_128x96_display_info =
{
  /* chip_enable_level = */ 0,
  /* chip_disable_level = */ 1,
  
  /* post_chip_enable_wait_ns = */ 20,
  /* pre_chip_disable_wait_ns = */ 15,
  /* reset_pulse_width_ms = */ 100, 	
  /* post_reset_wait_ms = */ 100, 		/**/
  /* sda_setup_time_ns = */ 100,		/* ssd1329  */
  /* sck_pulse_width_ns = */ 100,	/* ssd1329  */
  /* sck_clock_hz = */ 4000000UL,	/* since Arduino 1.6.0, the SPI bus speed in Hz. Should be  1000000000/sck_pulse_width_ns */
  /* spi_mode = */ 0,		/* active high, rising edge */
  /* i2c_bus_clock_100kHz = */ 4,
  /* data_setup_time_ns = */ 40,
  /* write_pulse_width_ns = */ 60,	/* ssd1329 */
  /* tile_width = */ 16,
  /* tile_height = */ 12,
  /* default_x_offset = */ 0,		/* x_offset is used as y offset for the ssd1329 */
  /* flipmode_x_offset = */ 0,		/* x_offset is used as y offset for the ssd1329 */
  /* pixel_width = */ 128,
  /* pixel_height = */ 96
};

uint8_t u8x8_d_ssd1329_128x96_noname(u8x8_t *u8x8, uint8_t msg, uint8_t arg_int, void *arg_ptr)
{
    if ( msg == U8X8_MSG_DISPLAY_SETUP_MEMORY )
    {
      u8x8_d_helper_display_setup_memory(u8x8, &u8x8_ssd1329_128x96_display_info);
      return 1;
    }
    return u8x8_d_ssd1329_128x96_generic(u8x8, msg, arg_int, arg_ptr);
}

/*=================================================*/
/* 
  SSD1329 with 96x96 
  For this display, the x_offset has been reverted to its original meaning!

  https://github.com/olikraus/u8g2/issues/1511

  FlipMode 1 probably does not work, see issue
*/

static const uint8_t u8x8_d_ssd1329_96x96_flip0_seq[] = {
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  U8X8_CA(0x0a2, 0x000),		/* display offset, shift mapping ram counter */
  U8X8_CA(0x0a1, 0x000),		/* display start line */
  U8X8_CA(0x0a0, 0x042),		/* remap */
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};

static const uint8_t u8x8_d_ssd1329_96x96_flip1_seq[] = {
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  U8X8_CA(0x0a2, 0x060),		/* display offset, shift mapping ram counter */
  U8X8_CA(0x0a1, 0x000),		/* display start line */
  U8X8_CA(0x0a0, 0x051),		/* remap */
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};


static const uint8_t u8x8_d_ssd1329_96x96_noname_init_seq[] = {
    
  U8X8_START_TRANSFER(),             	/* enable chip, delay is part of the transfer start */
  
  
  U8X8_C(0x0ae),		                /* display off */
  U8X8_CA(0x0b3, 0x0f0),		/* set display clock divide ratio/oscillator frequency, see #1511*/
  U8X8_CA(0x0a8, 0x05f),		/* multiplex ratio: 0x03f * 1/64 duty */ 
  U8X8_CA(0x0a2, 0x000),		/* display offset, shift mapping ram counter */
  U8X8_CA(0x0a1, 0x000),		/* display start line */
  U8X8_CA(0x0ad, 0x002),		/* master configuration: disable embedded DC-DC, enable internal VCOMH */
  U8X8_CA(0x0a0, 0x042),		/* remap configuration, horizontal address increment (bit 2 = 0), enable nibble remap (upper nibble is left, bit 1 = 1) */
  U8X8_C(0x086),				/* full current range (0x084, 0x085, 0x086) */
#ifdef removed
  U8X8_C(0x0b8),				/* set gray scale table */
    U8X8_A(1),				/* */
    U8X8_A(5),				/* */
    U8X8_A(10),				/* */
    U8X8_A(14),				/* */
    U8X8_A(19),				/* */
    U8X8_A(23),				/* */
    U8X8_A(28),				/* */
    U8X8_A(32),				/* */
    U8X8_A(37),				/* */
    U8X8_A(41),				/* */
    U8X8_A(46),				/* */
    U8X8_A(50),				/* */
    U8X8_A(55),				/* */
    U8X8_A(59),				/* */
    U8X8_A(63),				/* */
#endif 

  U8X8_C(0x0b7),				/* set default gray scale table */
    
  U8X8_CA(0x081, 0x070),		/* contrast, brightness, 0..255 */
  U8X8_CA(0x0b2, 0x023),		/* frame frequency (row period), see #1511 */
  U8X8_CA(0x0b1, 0x021),                    /* phase length, see #1511 */
  U8X8_CA(0x0bc, 0x010),                    /* pre-charge voltage level */
  U8X8_CA(0x0b4, 0x002),                    /* set pre-charge compensation level (not documented in the SDD1325 datasheet, but used in the NHD init seq.) */
  U8X8_CA(0x0b0, 0x028),                    /* enable pre-charge compensation (not documented in the SDD1325 datasheet, but used in the NHD init seq.) */
  U8X8_CA(0x0be, 0x01f),                     /* VCOMH voltage */
  U8X8_CA(0x0bf, 0x002|0x00d),           /* VSL voltage level (not documented in the SDD1325 datasheet, but used in the NHD init seq.) */
  U8X8_C(0x0a4),				/* normal display mode */
    
  U8X8_CA(0x023, 0x003),		/* graphics accelleration: fill pixel */
    
  U8X8_END_TRANSFER(),             	/* disable chip */
  U8X8_END()             			/* end of sequence */
};



static uint8_t u8x8_d_ssd1329_96x96_generic(u8x8_t *u8x8, uint8_t msg, uint8_t arg_int, void *arg_ptr)
{
  uint8_t x, y, c;
  uint8_t *ptr;
  switch(msg)
  {
    /* handled by the calling function
    case U8X8_MSG_DISPLAY_SETUP_MEMORY:
      u8x8_d_helper_display_setup_memory(u8x8, &u8x8_ssd1329_128x96_nhd_display_info);
      break;
    */
    case U8X8_MSG_DISPLAY_INIT:
      u8x8_d_helper_display_init(u8x8);
      u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_96x96_noname_init_seq);    
      break;
    case U8X8_MSG_DISPLAY_SET_POWER_SAVE:
      if ( arg_int == 0 )
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_nhd_powersave0_seq);
      else
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_128x96_nhd_powersave1_seq);
      break;
    case U8X8_MSG_DISPLAY_SET_FLIP_MODE:
      if ( arg_int == 0 )
      {
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_96x96_flip0_seq);
	u8x8->x_offset = u8x8->display_info->default_x_offset;
      }
      else
      {
	u8x8_cad_SendSequence(u8x8, u8x8_d_ssd1329_96x96_flip1_seq);
	u8x8->x_offset = u8x8->display_info->flipmode_x_offset;
      }
      break;
#ifdef U8X8_WITH_SET_CONTRAST
    case U8X8_MSG_DISPLAY_SET_CONTRAST:
      u8x8_cad_StartTransfer(u8x8);
      u8x8_cad_SendCmd(u8x8, 0x081 );
      u8x8_cad_SendArg(u8x8, arg_int );	/* ssd1329 has range from 0 to 255 */
      u8x8_cad_EndTransfer(u8x8);
      break;
#endif
    case U8X8_MSG_DISPLAY_DRAW_TILE:
      u8x8_cad_StartTransfer(u8x8);
      x = ((u8x8_tile_t *)arg_ptr)->x_pos;
      x *= 4;
      x += u8x8->x_offset;
      
      y = (((u8x8_tile_t *)arg_ptr)->y_pos);
      
      y *= 8;
    
      
      do
      {
	c = ((u8x8_tile_t *)arg_ptr)->cnt;
	ptr = ((u8x8_tile_t *)arg_ptr)->tile_ptr;

	do
	{
	  if ( ptr[0] | ptr[1] | ptr[2] | ptr[3] | ptr[4] | ptr[5] | ptr[6] | ptr[7] )
	  {
	    /* draw the tile if pattern is not zero for all bytes */
	    u8x8_cad_SendCmd(u8x8, 0x015 );	/* set column address */
	    u8x8_cad_SendArg(u8x8, x );	/* start */
	    u8x8_cad_SendArg(u8x8, x+3 );	/* end */

	    u8x8_cad_SendCmd(u8x8, 0x075 );	/* set row address */
	    u8x8_cad_SendArg(u8x8, y);
	    u8x8_cad_SendArg(u8x8, y+7);
	    
	    
	    u8x8_cad_SendData(u8x8, 32, u8x8_ssd1329_8to32(u8x8, ptr));
	  }
	  else
	  {
	    /* tile is empty, use the graphics acceleration command */
	    /* are this really available on the SSD1329??? */
	    u8x8_cad_SendCmd(u8x8, 0x024 );	// draw rectangle
	    u8x8_cad_SendArg(u8x8, x );	
	    u8x8_cad_SendArg(u8x8, y );	
	    u8x8_cad_SendArg(u8x8, x+3 );	
	    u8x8_cad_SendArg(u8x8, y+7 );	
	    u8x8_cad_SendArg(u8x8, 0 );	// clear	    
	  }
	  ptr += 8;
	  x += 4;
	  c--;
	} while( c > 0 );
	
	//x += 4;
	arg_int--;
      } while( arg_int > 0 );
      
      u8x8_cad_EndTransfer(u8x8);
      break;
    default:
      return 0;
  }
  return 1;
}


static const u8x8_display_info_t u8x8_ssd1329_96x96_display_info =
{
  /* chip_enable_level = */ 0,
  /* chip_disable_level = */ 1,
  
  /* post_chip_enable_wait_ns = */ 20,
  /* pre_chip_disable_wait_ns = */ 15,
  /* reset_pulse_width_ms = */ 100, 	
  /* post_reset_wait_ms = */ 100, 		/**/
  /* sda_setup_time_ns = */ 100,		/* ssd1329  */
  /* sck_pulse_width_ns = */ 100,	/* ssd1329  */
  /* sck_clock_hz = */ 4000000UL,	/* since Arduino 1.6.0, the SPI bus speed in Hz. Should be  1000000000/sck_pulse_width_ns */
  /* spi_mode = */ 0,		/* active high, rising edge */
  /* i2c_bus_clock_100kHz = */ 4,
  /* data_setup_time_ns = */ 40,
  /* write_pulse_width_ns = */ 60,	/* ssd1329 */
  /* tile_width = */ 12,
  /* tile_height = */ 12,
  /* default_x_offset = */  0,          /* x offset for flip mode 0 */
  /* flipmode_x_offset = */ 16,		/* x offset for flip mode 1 */ 
  /* pixel_width = */ 96,
  /* pixel_height = */ 96
};

uint8_t u8x8_d_ssd1329_96x96_noname(u8x8_t *u8x8, uint8_t msg, uint8_t arg_int, void *arg_ptr)
{
    if ( msg == U8X8_MSG_DISPLAY_SETUP_MEMORY )
    {
      u8x8_d_helper_display_setup_memory(u8x8, &u8x8_ssd1329_96x96_display_info);
      return 1;
    }
    return u8x8_d_ssd1329_96x96_generic(u8x8, msg, arg_int, arg_ptr);
}
