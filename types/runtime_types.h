#ifndef RUNTIME_TYPES_H
# define RUNTIME_TYPES_H
#endif

/****************************************************************************
 * Types for the JVM runtime                                                *
 *                                                                          *
 * (C) 2014 University of Massachusetts, Amherst                            *
 * Authored by Levi Ramsey <lramsey@umass.edu>                              *
 ****************************************************************************/

#include "jvm_types.h"

/* The run-time stack is a [singly] linked-list on the [JVM] heap */
typedef struct runtime_stack_frame {
	runtime_stack_frame *next;
} runtime_stack;

/* Per-thread data */
typedef struct jvm_thread {
	jvm_return_address_wide pc;		/* Program counter */
	runtime_stack *top_of_stack;
} jvm_thread;

/* Global heap */
typedef struct heap {
} jvm_heap;
