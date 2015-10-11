#ifndef PD_MACHINE_H
#define PD_MACHINE_H

// for #pragma pack(ALIGNED_LENGTH), for example, esp8266 should be 1
#define ALIGNED_LENGTH

// some platform need this prefix between function name and return type
#define FUNCTION_ATTRIBUTE

// different platform has its own define of these functions.
#define pd_malloc malloc
#define pd_free free
#define pd_memcpy memcpy
#define pd_printf printf
#define pd_memcmp memcmp
#define pd_memset memset
uint64_t pd_get_timestamp();

#endif

