// Ficheiro:  projeto.c
// Descricao: Trabalho prático — equivalente em C do Projeto.S
// Autor:     A54193 & A53107

#include <stdint.h>
#include <stdbool.h>

// ── Hardware addresses (memory-mapped I/O) ───────────────────────────────────
#define INPORT_ADDRESS   0xFF80
#define OUTPORT_ADDRESS  0xFFC0
#define PTC_BASE         0xFF00
#define PTC_TCR          0x00
#define PTC_TMR          0x02
#define PTC_TC           0x04
#define PTC_TIR          0x06

static volatile uint8_t * const INPORT  = (volatile uint8_t*)INPORT_ADDRESS;
static volatile uint8_t * const OUTPORT = (volatile uint8_t*)OUTPORT_ADDRESS;
static volatile uint8_t * const PTC     = (volatile uint8_t*)PTC_BASE;

// ── LED colours / masks ───────────────────────────────────────────────────────
#define LED0_MASK  0x01
#define LED1_MASK  0x02
#define LED2_MASK  0x04
#define LED3_MASK  0x08
#define ALL_LEDS   (LED0_MASK | LED1_MASK | LED2_MASK | LED3_MASK)

#define LED_BLACK   0x00
#define LED_RED     0x01
#define LED_GREEN   0x02
#define LED_YELLOW  0x03

// ── Persistent state (mirrors .data section) ─────────────────────────────────
static uint8_t  led_state     = 0;
static uint32_t prev_buttons  = 0x0F;  // all buttons released
static uint32_t random_state  = 0;
static uint32_t sleep_count   = 0;
static uint32_t sleep_running = 0;

// ── Low-level I/O ─────────────────────────────────────────────────────────────
static void outport_write(uint8_t val) { *OUTPORT = val; }
static uint8_t inport_read(void) { return *INPORT; }

// ── pTC timer ─────────────────────────────────────────────────────────────────
static void ptc_init(void) {
    PTC[PTC_TCR] = 0x01;  // stop counter
    PTC[PTC_TMR] = 10;    // match value
    PTC[PTC_TIR] = 0;     // clear interrupt
}

static void ptc_start(uint32_t count) {
    if (count == 0) return;
    sleep_count   = count;
    sleep_running = 1;
    PTC[PTC_TCR]  = 0x01;  // stop first
    PTC[PTC_TIR]  = 0;     // clear interrupt
    PTC[PTC_TCR]  = 0x00;  // start
}

static bool ptc_done(void) {
    return sleep_running == 0;
}

// ── pTC interrupt service routine ─────────────────────────────────────────────
void ptc_isr(void) {
    PTC[PTC_TIR] = 0;      // clear interrupt flag
    sleep_count--;
    if (sleep_count == 0) {
        PTC[PTC_TCR]  = 0x01;  // stop timer
        sleep_running = 0;
    }
}

// ── Sleep (busy-wait on timer ISR flag) ───────────────────────────────────────
static void sleep(uint32_t ms) {
    ptc_start(ms);
    while (!ptc_done()) {}
}

// ── LED control ───────────────────────────────────────────────────────────────
// mask : which LEDs to update (bit0=LED0 .. bit3=LED3)
// colour: LED_BLACK / LED_RED / LED_GREEN / LED_YELLOW
static void led(uint8_t mask, uint8_t colour) {
    uint8_t state = led_state;

    if (mask & LED0_MASK) {
        state = (state & 0xFC) | (colour & 0x03);
    }
    if (mask & LED1_MASK) {
        state = (state & 0xF3) | ((colour << 2) & 0x0C);
    }
    if (mask & LED2_MASK) {
        state = (state & 0xCF) | ((colour << 4) & 0x30);
    }
    if (mask & LED3_MASK) {
        state = (state & 0x3F) | ((colour << 6) & 0xC0);
    }
    led_state = state;
    outport_write(state);
}

static void clear(uint8_t mask) { led(mask, LED_BLACK); }

static void blink(uint8_t colour, uint32_t ms) {
    led(ALL_LEDS, colour);
    sleep(ms);
    clear(ALL_LEDS);
    sleep(ms);
}

// ── Button edge detection (falling edge = button pressed) ─────────────────────
static uint8_t check_buttons(void) {
    uint8_t current = inport_read() & 0x0F;
    uint8_t clicks  = prev_buttons & (~current & 0x0F);
    prev_buttons = current;
    return clicks;
}

// ── PRNG (xorshift) ───────────────────────────────────────────────────────────
static void init_random(uint32_t seed) { random_state = seed; }

static uint32_t get_random(void) {
    uint32_t x = random_state;
    x ^= (x << 7);
    x ^= (x >> 5);
    x ^= (x << 3);
    random_state = x;
    return x;
}

// ── Forward declarations ───────────────────────────────────────────────────────
static void game_won(void);
static void game_lost(void);

// ── Win / lose screens ────────────────────────────────────────────────────────
static void game_won(void) {
    blink(LED_GREEN, 5);
    blink(LED_GREEN, 5);
    blink(LED_GREEN, 5);
    // falls through to main() — equivalent to "b reset"
}

static void game_lost(void) {
    blink(LED_RED, 5);
    blink(LED_RED, 5);
    blink(LED_RED, 5);
    // falls through to main() — equivalent to "b reset"
}

// ── Main ─────────────────────────────────────────────────────────────────────
void main(void) {

restart:
    ptc_init();
    // (interrupts enabled here in assembly via CPSR)

    // Show yellow on all LEDs at startup
    clear(ALL_LEDS);
    led(ALL_LEDS, LED_YELLOW);

    // Wait for any button press
    while (check_buttons() == 0) {}

    clear(ALL_LEDS);

    // Wait for button 1 specifically; count iterations as entropy seed
    uint32_t r5 = 0;
    do {
        r5++;
    } while (check_buttons() != 0x01);

    // Use iteration count as seed (unless it's zero — use 0 then)
    uint32_t seed = (r5 != 0) ? r5 : 0;
    init_random(seed);

    // ── game_starts: placeholder — jumps straight to won ─────────────────────
    game_won();

    goto restart;  // "b reset" in assembly
}