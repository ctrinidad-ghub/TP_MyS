/* 
 * TP Microarquitecturas y Softcores Demo
 * 
 *
 *    - Use ALT versions of stdio routines:
 *
 *           Function                  Description
 *        ===============  =====================================
 *        alt_printf       Only supports %s, %x, and %c ( < 1 Kbyte)
 *        alt_putstr       Smaller overhead than puts with direct drivers
 *                         Note this function doesn't add a newline.
 *        alt_putchar      Smaller overhead than putchar with direct drivers
 *        alt_getchar      Smaller overhead than getchar with direct drivers
 *
 */

#include "sys/alt_stdio.h"
#include "stdio.h"
#include "system.h"
#include "io.h"

//  MSG_1
#define MSG_1_1  "+------------------+"
#define MSG_1_2  "| Trabajo Practico |"
#define MSG_1_3  "|       MyS        |"
#define MSG_1_4  "+------------------+"

//  MSG_2
#define MSG_2_1  "+------------------+"
#define MSG_2_2  "| Segundo mensaje  |"
#define MSG_2_3  "|   y... ultimo    |"
#define MSG_2_4  "+------------------+"

// LCD address
#define CHAR_REG 		0x0
#define POSITION_REG 	0x1
#define STATUS_REG 		0x2

#define BUSY 0x1
#define KEY0 0x4
#define KEY3 0x2

void lcdData( uint8_t data )
{
	IOWR(LCD_WRAPPER_0_BASE, CHAR_REG, data);
	while ((IORD(LCD_WRAPPER_0_BASE, STATUS_REG) & BUSY) == BUSY);
}

void lcdSendString( const char* str )
{
   uint32_t i = 0;
   while( str[i] != 0 ) {
	   lcdData( str[i] );
      i++;
   }
}

void lcdGoToXY( uint8_t x, uint8_t y ){
	IOWR(LCD_WRAPPER_0_BASE, POSITION_REG, x<<2 | y);
	while ((IORD(LCD_WRAPPER_0_BASE, STATUS_REG) & BUSY) == BUSY);
}

void lcd_init (void) {
	while ((IORD(LCD_WRAPPER_0_BASE, STATUS_REG) & BUSY) == BUSY);
}

char isPressedKEY0(void) {
	return (!((IORD(SWITCH_BASE, 0) & KEY0) == KEY0));
}

int main()
{ 

  alt_putstr("\n\n\n\n Inicializando Nios II y LCD \n");

  lcd_init ( );

  alt_putstr("\n Listo para la demo \n");

  alt_putstr("\n Pulse KEY0 para imprimir algo... \n\n\n");

  while (!isPressedKEY0( ));
  while (isPressedKEY0( ));

  alt_printf(" %s \n %s \n %s \n %s \n", MSG_1_1, MSG_1_2, MSG_1_3, MSG_1_4);

  lcdGoToXY( 0, 0 ); // x = 0, y = 0
  lcdSendString(MSG_1_1);
  lcdGoToXY( 0, 1 ); // x = 0, y = 1
  lcdSendString(MSG_1_2);
  lcdGoToXY( 0, 2 ); // x = 0, y = 2
  lcdSendString(MSG_1_3);
  lcdGoToXY( 0, 3 ); // x = 0, y = 3
  lcdSendString(MSG_1_4);

  alt_putstr("\n\n\n Pulse KEY0 para imprimir un segundo mensaje... \n\n\n");

  while (!isPressedKEY0( ));
  while (isPressedKEY0( ));

  alt_printf(" %s \n %s \n %s \n %s \n", MSG_2_1, MSG_2_2, MSG_2_3, MSG_2_4);

  lcdGoToXY( 0, 0 ); // x = 0, y = 0
  lcdSendString(MSG_2_1);
  lcdGoToXY( 0, 1 ); // x = 0, y = 1
  lcdSendString(MSG_2_2);
  lcdGoToXY( 0, 2 ); // x = 0, y = 2
  lcdSendString(MSG_2_3);
  lcdGoToXY( 0, 3 ); // x = 0, y = 3
  lcdSendString(MSG_2_4);

  alt_putstr("\n\n\n Fin de la demo \n\n\n");

  /* Event loop never exits. */
  while (1);

  return 0;
}
