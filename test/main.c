#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <inttypes.h>
#include <sys/mman.h>


// #define I2C_CTRL_TX_ACK     (1 << 7)
// #define I2C_CTRL_RX_ACK     (1 << 6)
// 
// #define I2C_CTRL_IDLE       (1 << 3)
// #define I2C_CTRL_BUSY       (1 << 2)
// #define I2C_CTRL_FEED       (1 << 1)
// #define I2C_CTRL_RSTN       (1 << 0)

#define I2C_CTRL_TX_ACK     0b10000000
#define I2C_CTRL_RX_ACK     0b01000000

#define I2C_CTRL_IDLE       0b00001000
#define I2C_CTRL_BUSY       0b00000100
#define I2C_CTRL_FEED       0b00000010
#define I2C_CTRL_RSTN       0b00000001

#define I2C_DATA_RX_SHIFT   16
#define I2C_DATA_TX_SHIFT   8
#define I2C_DATA_ADDR_SHIFT 0

volatile unsigned int *i2c_mmio;
volatile unsigned int *i2c_ctrl;
volatile unsigned int *i2c_data;
volatile unsigned int *i2c_dbg; 

int
i2c_write(char addr, char *write_data, size_t num)
{
	size_t i;

	*i2c_ctrl = I2C_CTRL_RSTN | I2C_CTRL_FEED;
	while ((*i2c_ctrl & I2C_CTRL_IDLE) == I2C_CTRL_IDLE) { /* wait controller to finish previous transaction */
	}

	*i2c_ctrl = I2C_CTRL_RSTN;
	while ((*i2c_ctrl & I2C_CTRL_BUSY) == I2C_CTRL_BUSY) { /* wait controller to become not busy */
	}

	*i2c_data = 0x00000000 | (addr << 1);
	while ((*i2c_ctrl & I2C_CTRL_BUSY) != I2C_CTRL_BUSY) { /* wait controller to become not busy */
	}
	while ((*i2c_ctrl & I2C_CTRL_BUSY) == I2C_CTRL_BUSY) { /* wait controller to become busy */
	}

	if ((*i2c_ctrl & I2C_CTRL_TX_ACK) == I2C_CTRL_TX_ACK) {
		*i2c_ctrl = 0;
		return -1;
	}

	for (i = 0; i < num; i++) {
		*i2c_data = write_data[i] << 8;

		while ((*i2c_ctrl & I2C_CTRL_BUSY) != I2C_CTRL_BUSY) { /* wait controller to become not busy */
		}
		while ((*i2c_ctrl & I2C_CTRL_BUSY) == I2C_CTRL_BUSY) { /* wait controller to become busy */
		}

		if ((*i2c_ctrl & I2C_CTRL_TX_ACK) == I2C_CTRL_TX_ACK) {
			*i2c_ctrl = 0;
			return -1;
		}
	}

	*i2c_ctrl = I2C_CTRL_RSTN | I2C_CTRL_FEED;
	while ((*i2c_ctrl & I2C_CTRL_IDLE) == I2C_CTRL_IDLE) { /* wait controller to finish previous transaction */
	}

	*i2c_ctrl = 0; /* reset the controller */

	return 0;
}

int
i2c_read(char addr, size_t num, char *buf)
{
	size_t i;

	*i2c_ctrl = I2C_CTRL_RSTN | I2C_CTRL_FEED;
	while ((*i2c_ctrl & I2C_CTRL_IDLE) == I2C_CTRL_IDLE) { /* wait controller to finish previous transaction */
	}

	*i2c_ctrl = I2C_CTRL_RSTN;
	while ((*i2c_ctrl & I2C_CTRL_BUSY) == I2C_CTRL_BUSY) { /* wait controller to become busy */
	}

	*i2c_data = (addr << 1) | 1;
	while ((*i2c_ctrl & I2C_CTRL_BUSY) != I2C_CTRL_BUSY) { /* wait controller to become not busy */
	}
	while ((*i2c_ctrl & I2C_CTRL_BUSY) == I2C_CTRL_BUSY) { /* wait controller to become busy */
	}

	if ((*i2c_ctrl & I2C_CTRL_TX_ACK) == I2C_CTRL_TX_ACK) {
		*i2c_ctrl = 0;
		return -1;
	}


	*i2c_ctrl = *i2c_ctrl & ~(I2C_CTRL_RX_ACK);
	for (i = 0; i < num; i++) {
		while ((*i2c_ctrl & I2C_CTRL_BUSY) != I2C_CTRL_BUSY) { /* wait controller to become busy */
		}
		while ((*i2c_ctrl & I2C_CTRL_BUSY) == I2C_CTRL_BUSY) { /* wait controller to become busy */
		}

		buf[i] = (*i2c_data >> 16) & 0xff;
	}

	*i2c_ctrl = I2C_CTRL_RSTN | I2C_CTRL_FEED;
	while ((*i2c_ctrl & I2C_CTRL_IDLE) == I2C_CTRL_IDLE) { /* wait controller to finish previous transaction */
	}

	*i2c_ctrl = 0; /* reset the controller */

	return 0;
}


int
main(int argc, const char *argv[])
{
	int fd, ret;
	size_t i;
	char buf[4];

	fd = open("/dev/mem", O_RDWR);
	if (!fd) {
		fprintf(stderr, "open(\"/dev/mem\", O_RDWR)\n");
		return -1;
	}

	i2c_mmio = (volatile uint32_t *) mmap(0, 0x1000,
					      PROT_READ | PROT_WRITE,
					      MAP_SHARED, fd, 0x43C00000);

	if (!i2c_mmio) {
		fprintf(stderr, "mmap\n");
		return -1;
	}

	i2c_ctrl = i2c_mmio;
	i2c_data = i2c_mmio + 1;
	i2c_dbg = i2c_mmio + 2;

	*i2c_ctrl = 0b00000000;
	printf("%p, %p\n", i2c_ctrl, i2c_data);
	printf("%x, %x\n", *i2c_ctrl, *i2c_data);

	buf[0] = 0x01;
	buf[1] = 0x02;
	buf[2] = 0xd2;
	ret = i2c_write(0x50, buf, 3);
	if (ret) {
		fprintf(stderr, "Write got NAK\n");
	}

	buf[0] = 0x01;
	buf[1] = 0x01;
	buf[2] = 0x55;
	ret = i2c_write(0x50, buf, 3);
	if (ret) {
		fprintf(stderr, "Write got NAK\n");
	}

	usleep(3000);

	ret = i2c_write(0x50, buf, 2);
	if (ret) {
		fprintf(stderr, "Write got NAK\n");
	}
	usleep(10);

	ret = i2c_read(0x50, 2, buf);
	if (ret) {
		fprintf(stderr, "Addr Read got NAK\n");
	}
	*i2c_ctrl = 0;

	for (i = 0; i < 2; i++) {
		printf("%02x ", buf[i]);
	}
	printf("\n");

	close(fd);

	return 0;
}
