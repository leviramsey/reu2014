#ifndef JVM_TYPES_H
# define JVM_TYPES_H
#endif

/****************************************************************************
 * Primitive types in the JVM                                               *
 *                                                                          *
 * (C) 2014 University of Massachusetts, Amherst                            *
 * Authored by Levi Ramsey <lramsey@umass.edu>                              *
 ****************************************************************************/

typedef char jvm_byte;
typedef short jvm_short;
typedef int jvm_int;
typedef long long jvm_long;
typedef unsigned short jvm_char;
typedef float jvm_float;
typedef double jvm_double;
typedef jvm_int jvm_return_address;
typedef jvm_long jvm_return_address_wide;

struct array_reference {
};

typedef struct array_reference * jvm_array_reference;

struct object_reference {
};

typedef struct object_reference * jvm_object_reference;

struct interface_reference {
};

typedef struct interface_reference * jvm_interface_reference;

#ifdef TEST_JVM_TYPES_H
/* You may need to symlink a .c file to this header in order to get this to
 *  work...
 */
# include <stdio.h>
# include <stdlib.h>

# define VERIFY_TYPE(TYPE, SHOULD_BE) \
	printf("sizeof(%s): %d, should be %d\n", #TYPE, sizeof(jvm_ ## TYPE), SHOULD_BE)

int main(int argc, char **argv)
{
	VERIFY_TYPE(byte, 1);
	VERIFY_TYPE(short, 2);
	VERIFY_TYPE(int, 4);
	VERIFY_TYPE(long, 8);
	VERIFY_TYPE(char, 2);
	printf("sizeof(array_reference): %d\n", sizeof(jvm_array_reference));
}
#endif
