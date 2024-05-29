void SSI2_Init(void) {
    int dummy;

    SYSCTL_RCGCSSI_R |= (1<<2);
    SYSCTL_RCGCGPIO_R |= (1<<1);

    dummy = SYSCTL_RCGCSSI_R;
    dummy = SYSCTL_RCGCGPIO_R;

    GPIO_PORTB_AMSEL_R &= ~0xf0;

    GPIO_PORTB_AFSEL_R |= 0b11110000;

    GPIO_PORTB_PCTL_R |= (2<<16) | (2<<20) | (2<<24) | (2<<28);

    GPIO_PORTB_DEN_R |= (1<<4) | (1<<5) | (1<<6) | (1<<7);

    GPIO_PORTB_DIR_R |= 0b10110000;

    SSI2_CR1_R = 0x00000000;

    SSI2_CC_R = 0x00;

    SSI2_CPSR_R = 2;

    SSI2_CR0_R = 0x0000f;

    SSI2_CR1_R |= 2;

}

void SSI2_Transfer(INT16U data) {

        while((SSI2_SR_R & 2) == 0); // Bit 1 is the TNF (Transmit FIFO Not Full) flag
        SSI2_DR_R = data;

}
