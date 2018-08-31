#pragma once
#include "zip.h"

typedef unsigned char byte;
typedef unsigned short word;
#define TRACKS      77
#define DDSECTORS   52
#define SECTORSIZE  128


enum {
    END_BLOCK = -1,
    END_FLUX = -2,
 };

enum {
    HASID = 1,
    HASDATA = 2
};


typedef struct {
    byte smap[DDSECTORS];               // physical slot to sector map
    bool hasData[DDSECTORS];            // in physical slot order
    byte track[DDSECTORS * SECTORSIZE]; // in physical slot order
} imd_t;


enum {      // bit combinations returned by nextBits
    BIT0,
    BIT0M,  // special 0 bit used in marker
    BIT1,
    BIT1S,  // special to note bit 1 on which resync happend
    BIT00,
    BIT01,
    BITEND, // no more bits
    BITBAD,  // illegal flux pattern

    BITSTART,   // used to signal start of bitstream for bitLogging
    BITFLUSH,    // used to flush bitstream for bitLogging
    BITFLUSH_1   // variant that flushes all but last bit (used for marker alignment)

};

extern int debug;
extern bool showSectorMap;

#define LINELEN 80
enum {
    ALWAYS = 0, MINIMAL, VERBOSE, VERYVERBOSE
};

int nextBits();
size_t seekBlock(int blk);
void resetFlux();
void freeMem();
size_t where();
long when();
void *xalloc(void *buf, size_t size);
size_t readFluxBuffer(byte *buf, size_t bufsize);

int x8ByteTime();
void addIMD(int track, imd_t *trackPtr, const char *fname);
void WriteImgFile(char *fname, char *comment);
_declspec(noreturn) void error(char *fmt, ...);
void logger(int level, char *fmt, ...);
void displayHist(int levels);
void resetIMD();

int bitLog(int bits);